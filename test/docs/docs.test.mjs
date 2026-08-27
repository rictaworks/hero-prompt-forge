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

test("README に書いた経路は、すべて実装されています", () => {
  const routes = read("src", "backend", "config", "routes.rb");
  const controllers = join(ROOT, "src", "backend", "app", "controllers");

  // 経路の定義そのものを読み解かず、**要となる語が定義に現れること**を見ます。
  const missing = documentedEndpoints().filter(({ path }) => {
    const name = path.split("/").filter((part) => part && !part.startsWith(":")).at(-1);
    return !routes.includes(name) && !existsSync(join(controllers, `${name}_controller.rb`));
  });

  assert.deepEqual(
    missing.map((entry) => `${entry.verb} ${entry.path}`),
    [],
    "README に、経路の定義に無いエンドポイントが書かれています。",
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
