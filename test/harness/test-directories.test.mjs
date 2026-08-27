// `test/` 配下の置き場が、どこからも実行されないまま残ることを防ぎます（issue #142）。
//
// `test/` は 3 系統に分かれ、それぞれ別のコマンドで動きます。**束ねる仕組みが
// 無いと、新しい置き場を足したときに、実行されないまま気づけません。**
// `.claude/TEST-HARNESS-SAFETY.md` の TH2 が求める、探索カバレッジの回帰テストです。
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..", "..");
const TEST_ROOT = join(ROOT, "test");

/** Playwright が拾う置き場の形です。PR ごとのディレクトリが当たります。 */
const PLAYWRIGHT_DIRECTORY = /^pr/;

/** package.json の実行の定義です。 */
function scripts() {
  return JSON.parse(readFileSync(join(ROOT, "package.json"), "utf8")).scripts;
}

/** `test/` の直下にある置き場の名前です。 */
function directories() {
  return readdirSync(TEST_ROOT, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name);
}

/** その置き場を対象にする実行があるかどうかを返します。 */
function covered(name) {
  if (PLAYWRIGHT_DIRECTORY.test(name)) {
    return true;
  }
  return Object.values(scripts()).some((command) => command.includes(`test/${name}/`));
}

test("test/ の置き場は、すべていずれかの実行の対象です", () => {
  const uncovered = directories().filter((name) => !covered(name));

  assert.deepEqual(
    uncovered,
    [],
    `どの実行からも呼ばれない置き場があります: ${uncovered.join(", ")}。` +
      "package.json へ実行を足し、test:all からも呼ばれるようにしてください。",
  );
});

test("束ねる実行が、Playwright 以外のすべてを呼びます", () => {
  const all = scripts()["test:all"];
  const bundled = Object.keys(scripts()).filter(
    (name) => name.startsWith("test:") && !name.startsWith("test:e2e") && name !== "test:all",
  );
  const missing = bundled.filter((name) => !all.includes(`npm run ${name}`));

  assert.deepEqual(
    missing,
    [],
    `test:all から呼ばれていない実行があります: ${missing.join(", ")}。`,
  );
});

// **Playwright は束ねません。** 開発サーバーが動いていないと実行できず、
// 束ねると「サーバーが無い」だけで全体が落ちます。CI では別のジョブにします。
test("束ねる実行は、開発サーバーを要する Playwright を呼びません", () => {
  assert.equal(scripts()["test:all"].includes("test:e2e"), false);
});

// **ブラウザ操作の確認が、自動検査から呼ばれることを確かめます**（issue #173）。
//
// 束ねる実行（`test:all`）から外す判断は正しいのですが、**自動検査にも
// ジョブが無いと、一度も走らないまま取り込まれます。** 実際に PR #170 では、
// 「バックエンドのドメインを隠蔽する」という約束を守る唯一のテストが
// Playwright だけにあり、自動では動いていませんでした。
function workflow() {
  return readFileSync(join(ROOT, ".github", "workflows", "ci.yml"), "utf8");
}

test("自動検査が、ブラウザ操作の確認を走らせます", () => {
  assert.ok(
    workflow().includes("npx playwright test"),
    ".github/workflows/ci.yml に、Playwright を走らせる手順がありません。",
  );
});

test("ブラウザ操作の確認の接続先は、開発サーバーです", () => {
  const line = workflow()
    .split("\n")
    .find((text) => text.includes("E2E_BASE_URL:"));

  assert.ok(line, ".github/workflows/ci.yml が E2E_BASE_URL を与えていません。");
  assert.match(
    line,
    /https?:\/\/(localhost|127\.0\.0\.1)/,
    "接続先が開発サーバーではありません。本番へ向けて確認を流しません。",
  );
});

// **立ち上げてから確かめます。** 待たずに確認へ進むと、立ち上がりの遅さが
// 「画面が出ない」として現れます。
test("画面とバックエンドを起動してから、ブラウザ操作の確認を走らせます", () => {
  const text = workflow();
  const backend = text.indexOf("bin/rails server");
  const frontend = text.indexOf("npm run start");
  const check = text.indexOf("npx playwright test");

  assert.ok(backend > -1, "バックエンドを起動する手順がありません。");
  assert.ok(frontend > -1, "画面を起動する手順がありません。");
  assert.ok(
    backend < check && frontend < check,
    "起動より先にブラウザ操作の確認を走らせています。",
  );
});
