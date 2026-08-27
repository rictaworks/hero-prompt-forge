// **README と `SPEC/` に、未実装のものを書かないことを守ります**（CLAUDE.md、issue #78 ・ #79）。
//
// 文書は、書いた時点では正しくても、**実装が動いた日に黙って嘘になります。**
// 画面や経路が消えても、文書はそのまま残ります。**読んだ方が、無い画面を開きます。**
// ここでは「文書に書いた住所が、実装に実在すること」を確かめます。
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..", "..");

function read(...parts) {
  return readFileSync(join(ROOT, ...parts), "utf8");
}

/** README の「ページ一覧」の表から、画面の住所を取り出します。 */
function documentedPages() {
  const table = read("README.md").split("### 開発者用の管理画面")[0];
  const found = new Set();
  for (const match of table.matchAll(/\[(\/[a-z0-9/:_-]*)\]\(/g)) {
    found.add(match[1]);
  }
  return [...found];
}

/**
 * Next.js の画面の住所を数え上げます。
 *
 * `src/frontend/src/app` の下で `page.tsx` を持つディレクトリが、1 つの住所です。
 * 動く部分（`[id]`）は `:id` として書きます。
 */
function implementedPages() {
  const base = join(ROOT, "src", "frontend", "src", "app");
  const found = [];

  function walk(dir, path) {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      if (entry.isDirectory()) {
        walk(join(dir, entry.name), `${path}/${entry.name.replace(/^\[(.+)\]$/, ":$1")}`);
      } else if (entry.name === "page.tsx") {
        found.push(path === "" ? "/" : path);
      }
    }
  }

  walk(base, "");
  return found;
}

/** README の「API 一覧」の表から、経路を取り出します。 */
function documentedEndpoints() {
  const found = [];
  for (const match of read("README.md").matchAll(/`(GET|POST|PATCH|DELETE) (\/[a-z0-9/_:.-]+)`/g)) {
    found.push({ verb: match[1], path: match[2] });
  }
  return found;
}

test("README に書いた画面は、すべて実装されています", () => {
  const implemented = implementedPages();
  const missing = documentedPages().filter((path) => !implemented.includes(path));

  assert.deepEqual(
    missing,
    [],
    `README に、実装が無い画面が書かれています: ${missing.join(", ")}。` +
      "未実装のものを README へ書きません（CLAUDE.md）。",
  );
});

test("実装した画面は、すべて README に書かれています", () => {
  const documented = documentedPages();
  const undocumented = implementedPages().filter((path) => !documented.includes(path));

  assert.deepEqual(
    undocumented,
    [],
    `README に載っていない画面があります: ${undocumented.join(", ")}。` +
      "ページ一覧へ足してください。",
  );
});

/**
 * 実装している経路を数え上げます。
 *
 * **経路の定義（`routes.rb`）から組み立てます。** 末尾の語だけを見ると、
 * **定義していない動詞や、利用者向けには無い経路が素通りします**
 * （PR #185 のレビュー・提案 1）。
 */
function implementedEndpoints() {
  const routes = read("src", "backend", "config", "routes.rb");
  const found = [];

  // 直に書いた経路です（`get 'auth/start', to: ...`）。
  for (const match of routes.matchAll(/^\s*(get|post|patch|put|delete)\s+'([^']+)'/gm)) {
    const path = match[2].split(" =>")[0];
    found.push({ verb: match[1].toUpperCase(), path: `/${path.replace(/^\//, "")}` });
  }

  // 資源としてまとめた経路です。**`only:` に挙げた操作だけを数えます。**
  const ACTIONS = {
    index: { verb: "GET", suffix: "" },
    create: { verb: "POST", suffix: "" },
    show: { verb: "GET", suffix: "/:id" },
    update: { verb: "PATCH", suffix: "/:id" },
    destroy: { verb: "DELETE", suffix: "/:id" },
  };

  for (const match of routes.matchAll(/resources? :(\w+), only: %i\[([^\]]*)\]/g)) {
    const name = match[1];
    const singular = !match[0].startsWith("resources ");
    for (const action of match[2].trim().split(/\s+/).filter(Boolean)) {
      const shape = ACTIONS[action];
      if (!shape) {
        continue;
      }
      // 単数の資源（`resource :session`）は、識別子を取りません。
      found.push({ verb: shape.verb, path: `/${name}${singular ? "" : shape.suffix}` });
    }
  }

  return found;
}

test("README に書いた経路は、すべて実装されています", () => {
  const implemented = implementedEndpoints();
  const missing = documentedEndpoints().filter(
    ({ verb, path }) =>
      !implemented.some(
        (entry) => entry.verb === verb && path.endsWith(entry.path.replace(/^\//, "/")),
      ),
  );

  assert.deepEqual(
    missing.map((entry) => `${entry.verb} ${entry.path}`),
    [],
    "README に、経路の定義に無いエンドポイントが書かれています。",
  );
});

/**
 * 状態遷移図が、実装の定めと一致することを確かめます。
 *
 * **図は、実装が変わっても黙って残ります**（PR #185 のレビュー・提案 2）。
 * 遷移の定めは機械が読めますので、ここで突き合わせます。
 */
function implementedTransitions(file, constant) {
  const source = read("src", "backend", "app", "models", file);
  const block = source.slice(source.indexOf(`${constant} = {`));
  const found = [];

  for (const match of block.matchAll(/'(\w+)' => %w\[([^\]]*)\]/g)) {
    for (const to of match[2].trim().split(/\s+/).filter(Boolean)) {
      found.push(`${match[1]} --> ${to}`);
    }
  }
  for (const match of block.matchAll(/(\w+) => \[(\w+(?:, \w+)*)\]/g)) {
    for (const to of match[2].split(", ")) {
      found.push(`${match[1]} --> ${to}`);
    }
  }
  return found;
}

/** 状態遷移図に描かれた遷移です。 */
function documentedTransitions(names) {
  const text = read("SPEC", "state.md");
  const found = [];

  for (const match of text.matchAll(/^\s{4}(\w+) --> (\w+)/gm)) {
    if (names.includes(match[1]) && names.includes(match[2])) {
      found.push(`${match[1]} --> ${match[2]}`);
    }
  }
  return found;
}

test("生成リクエストの状態遷移図が、実装の定めと一致します", () => {
  const implemented = implementedTransitions("prompt_request.rb", "TRANSITIONS").map((line) =>
    line.replace(/\b(DRAFT|QUEUED|GENERATING|COMPLETED|DEGRADED_COMPLETED|FAILED|REJECTED|ARCHIVED)\b/g, (word) =>
      word.toLowerCase(),
    ),
  );
  const documented = documentedTransitions([
    "draft",
    "queued",
    "generating",
    "completed",
    "degraded_completed",
    "failed",
    "rejected",
    "archived",
  ]);

  assert.deepEqual(
    [...new Set(implemented)].sort(),
    [...new Set(documented)].sort(),
    "SPEC/state.md の生成リクエストの図が、実装の定めと食い違っています。",
  );
});

test("クォータの状態遷移図が、実装の定めを漏らしません", () => {
  const implemented = implementedTransitions("quota_consumption.rb", "TRANSITIONS");
  const documented = documentedTransitions(["reserved", "confirmed", "refunded"]);
  const missing = implemented.filter((line) => !documented.includes(line));

  assert.deepEqual(
    missing,
    [],
    `SPEC/state.md のクォータの図に、実装済みの遷移がありません: ${missing.join(", ")}。`,
  );
});

test("SPEC の図は、すべて Mermaid のコード塀で閉じています", () => {
  const documents = readdirSync(join(ROOT, "SPEC")).filter((name) => name.endsWith(".md"));

  for (const name of documents) {
    const fences = read("SPEC", name).match(/^```/gm) ?? [];

    assert.equal(
      fences.length % 2,
      0,
      `SPEC/${name} のコード塀が閉じていません。図が本文として表示されます。`,
    );
  }
});

test("SPEC の索引は、置いてある文書をすべて挙げます", () => {
  const index = read("SPEC", "README.md");
  const documents = readdirSync(join(ROOT, "SPEC"))
    .filter((name) => name.endsWith(".md") && name !== "README.md");
  const missing = documents.filter((name) => !index.includes(name));

  assert.deepEqual(
    missing,
    [],
    `SPEC/README.md に載っていない文書があります: ${missing.join(", ")}。`,
  );
});
