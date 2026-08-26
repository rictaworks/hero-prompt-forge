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
