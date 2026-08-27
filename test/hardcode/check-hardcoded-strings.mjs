#!/usr/bin/env node
/**
 * 文字列リテラルが設定ファイルへ分離されているかを検査します。
 *
 * 画面や応答に出る文言をコードへ直書きすると、言い回しの統一ができず、
 * 直すときに漏れが出ます。日本語を含む文字列リテラルを見つけたら失敗させます。
 *
 * 実行 : node test/hardcode/check-hardcoded-strings.mjs [検査対象のディレクトリ]
 */
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative, sep } from "node:path";

const JAPANESE = /[぀-ゟ゠-ヿ一-鿿]/;

/** 検査の対象です。 */
const TARGETS = [
  { dir: "src/backend/app", extensions: [".rb"], language: "ruby" },
  { dir: "src/backend/lib", extensions: [".rb"], language: "ruby" },
  // **画面の雛形も対象です**（PR #175 のレビュー・要修正 3）。
  // 管理画面は `.erb` で書きます。対象から外れていると、日本語を直書きしても
  // 気づけません。**`<%= t(...) %>` を通す決まりを、ここで守ります。**
  { dir: "src/backend/app/views", extensions: [".erb"], language: "erb" },
  { dir: "src/frontend/src", extensions: [".ts", ".tsx"], language: "typescript" },
];

/** 文言そのものを置く場所です。ここは検査しません。 */
const ALLOWED_PATHS = [
  join("src", "backend", "config", "locales"),
  join("src", "frontend", "src", "strings"),
];

/** テストは、期待する文言をそのまま書くため検査しません。 */
const TEST_FILE = /(\.test\.tsx?|_spec\.rb)$/;

/**
 * 開発者にだけ見える記述（記録の書式、実装の誤りを知らせる例外）は、
 * 行末にこの印を付けて対象から外します。
 *
 * 利用者に見せる文言には使いません。印を付けた行は、レビューで
 * 「本当に利用者へ見せないか」を確認します。
 */
const DEVELOPER_ONLY = "開発者向け";

function listFiles(dir, extensions) {
  let entries;
  try {
    entries = readdirSync(dir);
  } catch {
    return [];
  }
  return entries.flatMap((entry) => {
    const path = join(dir, entry);
    if (statSync(path).isDirectory()) {
      return listFiles(path, extensions);
    }
    return extensions.some((e) => path.endsWith(e)) ? [path] : [];
  });
}

function stripComments(line, language) {
  if (language === "ruby") {
    return line.replace(/#.*$/, "");
  }
  if (language === "erb") {
    // **雛形の注記（`<%# ... %>`）は対象外です。**
    return line.replace(/<%#[\s\S]*?%>/g, "");
  }
  return line.replace(/\/\/.*$/, "").replace(/\/\*.*?\*\//g, "");
}

/**
 * 雛形のタグの中から、属性の値を取り出します。
 *
 * **属性の中の文言も、利用者の目に触れます**（`alt` ・ `title` ・ `placeholder`）。
 * 地の文だけを見ると、`<img alt="直書き">` が素通りします（issue #177 の提案 12）。
 */
function findErbAttributes(part) {
  const found = [];
  for (const tag of part.match(/<[^>]*>/g) ?? []) {
    for (const match of tag.matchAll(/=\s*'([^']*)'|=\s*"([^"]*)"/g)) {
      const value = match[1] ?? match[2] ?? "";
      if (value.length > 0) {
        found.push(value);
      }
    }
  }
  return found;
}

/**
 * 雛形の中で、日本語が現れうる場所を取り出します。
 *
 * **`<% %>` の外に置かれた地の文と、`<% %>` の中の文字列リテラルの
 * どちらも見ます。** 地の文へ直に書いた日本語も、直書きです。
 *
 * **地の文に加えて、タグの属性の値も見ます。** 属性へ書いた日本語も直書きです。
 */
function findErbLiterals(line) {
  const found = [];
  const outside = line.replace(/<%[\s\S]*?%>/g, "\u0000");
  for (const part of outside.split("\u0000")) {
    found.push(...findErbAttributes(part));
    const text = part.replace(/<[^>]*>/g, "").trim();
    if (text.length > 0) {
      found.push(text);
    }
  }
  for (const block of line.match(/<%[\s\S]*?%>/g) ?? []) {
    for (const match of block.matchAll(/'([^']*)'|"([^"]*)"/g)) {
      const value = match[1] ?? match[2] ?? "";
      if (value.length > 0) {
        found.push(value);
      }
    }
  }
  return found;
}

function findLiterals(line, language) {
  if (language === "erb") {
    return findErbLiterals(line);
  }
  const pattern =
    language === "ruby"
      ? /'([^']*)'|"([^"]*)"/g
      : /'([^']*)'|"([^"]*)"|`([^`]*)`/g;
  const found = [];
  let match;
  while ((match = pattern.exec(line)) !== null) {
    const value = match[1] ?? match[2] ?? match[3] ?? "";
    if (value.length > 0) {
      found.push(value);
    }
  }
  return found;
}

export function scan(rootDir) {
  const violations = [];

  for (const target of TARGETS) {
    const dir = join(rootDir, target.dir);
    for (const file of listFiles(dir, target.extensions)) {
      const relativePath = relative(rootDir, file);
      if (ALLOWED_PATHS.some((allowed) => relativePath.startsWith(allowed + sep))) {
        continue;
      }
      if (TEST_FILE.test(relativePath)) {
        continue;
      }

      const lines = readFileSync(file, "utf8").split("\n");
      lines.forEach((line, index) => {
        if (line.includes(DEVELOPER_ONLY)) {
          return;
        }
        const code = stripComments(line, target.language);
        for (const literal of findLiterals(code, target.language)) {
          if (JAPANESE.test(literal)) {
            violations.push({
              file: relativePath,
              line: index + 1,
              literal,
            });
          }
        }
      });
    }
  }

  return violations;
}

const invokedDirectly = process.argv[1]?.endsWith("check-hardcoded-strings.mjs");

if (invokedDirectly) {
  const rootDir = process.argv[2] ?? process.cwd();
  const violations = scan(rootDir);

  if (violations.length > 0) {
    console.error("日本語を含む文字列リテラルが見つかりました。設定ファイルへ移してください。");
    console.error("  サービス中身側 : src/backend/config/locales/ja.yml");
    console.error("  画面側         : src/frontend/src/strings/ja.ts");
    console.error("");
    for (const v of violations) {
      console.error(`  ${v.file}:${v.line}  ${JSON.stringify(v.literal)}`);
    }
    process.exit(1);
  }

  console.log("日本語を含む文字列リテラルはありません。");
}
