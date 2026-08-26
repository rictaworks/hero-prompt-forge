// マージ前フックの挙動を確かめます（issue #122）。
//
// 記録の「## 判定」の節だけを読むこと、本文の他の箇所に現れる語では
// 止まらないことを固定します。
//
// **一時ディレクトリへ作った最小のリポジトリに対して実行します。**
// このリポジトリの review-records/ を対象にすると、記録が増減するたびに
// 結果が変わります（.claude/TEST-HARNESS-SAFETY.md の TH4）。
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const HOOK = join(HERE, "..", "..", "scripts", "hooks", "merge-review-gate.sh");

/**
 * マージの呼び出しを模したペイロードです。
 *
 * **配列をつないで組み立てています。リテラルで書かないでください。**
 * このファイルの中にコマンドをそのまま書くと、導入済みのマージ前フックが
 * 反応し、テストを実行するコマンド自体が止まります（実際に起きました）。
 */
const MERGE_COMMAND = ["gh", "pr", "merge"].join(" ");

/** 一時ディレクトリに、記録だけを持つ最小のリポジトリを作ります。 */
function makeRepo({ reviewer, checker = "# PR 整備\n" }) {
  const root = mkdtempSync(join(tmpdir(), "hpf-merge-gate-"));
  execFileSync("git", ["init", "--quiet", root]);
  mkdirSync(join(root, "review-records", "reviewer"), { recursive: true });
  mkdirSync(join(root, "review-records", "pr-checker"), { recursive: true });
  if (reviewer !== null) {
    writeFileSync(join(root, "review-records", "reviewer", "pr1.md"), reviewer);
  }
  if (checker !== null) {
    writeFileSync(join(root, "review-records", "pr-checker", "pr1.md"), checker);
  }
  return root;
}

/** フックを実行して終了コードを返します。 */
function runHook(root, command = `${MERGE_COMMAND} 1 --squash`) {
  const result = spawnSync("bash", [HOOK], {
    cwd: root,
    input: JSON.stringify({ tool_input: { command } }),
    encoding: "utf8",
    timeout: 20000,
  });
  return { code: result.status, stderr: result.stderr };
}

test("判定が合格なら通します", () => {
  const root = makeRepo({
    reviewer: "# コードレビュー\n\n## 判定\n\n合格\n\n## 指摘\n\nありません。\n",
  });
  assert.equal(runHook(root).code, 0);
});

test("判定の節の外に語があっても止めません", () => {
  const root = makeRepo({
    reviewer:
      "# コードレビュー\n\n## 判定\n\n合格\n\nマージを妨げる指摘はありません。\n\n## 所感\n\n不合格の指摘はありません。\n",
  });
  assert.equal(runHook(root).code, 0);
});

test("判定が芳しくない記録は止めます", () => {
  const root = makeRepo({
    reviewer: "# コードレビュー\n\n## 判定\n\n不合格\n\n## 指摘\n\n1 件あります。\n",
  });
  const { code, stderr } = runHook(root);
  assert.equal(code, 2);
  assert.match(stderr, /判定/);
});

// **許可制です。「合格」と明記されているときだけ通します。**
// 特定の語だけを止める形にすると、書かれ方の数だけ穴が空きます。
test("判定が「要修正」なら止めます", () => {
  const root = makeRepo({
    reviewer: "# コードレビュー\n\n## 判定\n\n要修正（1 件）です。\n",
  });
  assert.equal(runHook(root).code, 2);
});

test("判定が「保留」なら止めます", () => {
  const root = makeRepo({ reviewer: "# コードレビュー\n\n## 判定\n\n保留\n" });
  assert.equal(runHook(root).code, 2);
});

test("判定が「マージ不可」なら止めます", () => {
  const root = makeRepo({ reviewer: "# コードレビュー\n\n## 判定\n\nマージ不可\n" });
  assert.equal(runHook(root).code, 2);
});

test("判定が「条件付き合格」なら通します", () => {
  const root = makeRepo({ reviewer: "# コードレビュー\n\n## 判定\n\n条件付き合格\n" });
  assert.equal(runHook(root).code, 0);
});

// 記録の中でフックの書式を例示しても、それを判定として拾いません。
test("コードの塀の中の見出しは、判定の節として拾いません", () => {
  const root = makeRepo({
    reviewer: "# コードレビュー\n\n## 書式の例\n\n```\n## 判定\n\n合格\n```\n\n## 所感\n\nありません。\n",
  });
  assert.equal(runHook(root).code, 2);
});

test("見出しが一行形式なら止めます", () => {
  const root = makeRepo({ reviewer: "# コードレビュー\n\n## 判定 : 合格\n\n指摘はありません。\n" });
  assert.equal(runHook(root).code, 2);
});

test("判定の節が無ければ止めます", () => {
  const root = makeRepo({ reviewer: "# コードレビュー\n\n## 所感\n\n合格です。\n" });
  assert.equal(runHook(root).code, 2);
});

test("判定の節が空なら止めます", () => {
  const root = makeRepo({
    reviewer: "# コードレビュー\n\n## 判定\n\n## 指摘\n\nありません。\n",
  });
  assert.equal(runHook(root).code, 2);
});

test("reviewer の記録が無ければ止めます", () => {
  const root = makeRepo({ reviewer: null });
  assert.equal(runHook(root).code, 2);
});

test("pr-checker の記録が無ければ止めます", () => {
  const root = makeRepo({ reviewer: "## 判定\n\n合格\n", checker: null });
  assert.equal(runHook(root).code, 2);
});

test("マージの呼び出しでなければ対象外です", () => {
  const root = makeRepo({ reviewer: null, checker: null });
  assert.equal(runHook(root, "git status").code, 0);
});

test("PR 番号が無ければ止めます", () => {
  const root = makeRepo({ reviewer: "## 判定\n\n合格\n" });
  assert.equal(runHook(root, `${MERGE_COMMAND} --squash`).code, 2);
});

// **最後の判定の節だけを読みます**（issue #142）。
// 本プロジェクトは、再レビューの結果を同じ記録へ追記します。
test("追記された記録は、最後の判定だけを読みます", () => {
  const root = makeRepo({
    reviewer:
      "# コードレビュー\n\n## 判定\n\n要修正\n\n1 件あります。\n\n---\n\n## 判定\n\n合格\n\n直っています。\n",
  });
  assert.equal(runHook(root).code, 0);
});

test("最後の判定が芳しくなければ、先に合格があっても止めます", () => {
  const root = makeRepo({
    reviewer: "# コードレビュー\n\n## 判定\n\n合格\n\n---\n\n## 判定\n\n要修正\n",
  });
  assert.equal(runHook(root).code, 2);
});

// **先頭行が既定の語と一致することを求めます**（issue #142）。
// 語の有無で見ると、否定した書き方が通ります。
test("判定を否定した書き方は止めます", () => {
  const root = makeRepo({
    reviewer: "# コードレビュー\n\n## 判定\n\n合格ではありません\n",
  });
  const { code, stderr } = runHook(root);
  assert.equal(code, 2);
  assert.match(stderr, /既定の語/);
});

test("合格に届かないと書いた記録は止めます", () => {
  const root = makeRepo({
    reviewer: "# コードレビュー\n\n## 判定\n\n要修正のため合格に届きません\n",
  });
  assert.equal(runHook(root).code, 2);
});

test("強調の記号が付いていても読めます", () => {
  const root = makeRepo({ reviewer: "# コードレビュー\n\n## 判定\n\n**合格**\n" });
  assert.equal(runHook(root).code, 0);
});

test("末尾の句点が付いていても読めます", () => {
  const root = makeRepo({ reviewer: "# コードレビュー\n\n## 判定\n\n**条件付き合格。**\n" });
  assert.equal(runHook(root).code, 0);
});

test("先頭行に理由まで書いてあれば止めます", () => {
  const root = makeRepo({
    reviewer: "# コードレビュー\n\n## 判定\n\n**合格** です。マージして構いません。\n",
  });
  assert.equal(runHook(root).code, 2);
});

test("空行を挟んでも、最初の中身のある行を読みます", () => {
  const root = makeRepo({ reviewer: "# コードレビュー\n\n## 判定\n\n\n\n合格\n" });
  assert.equal(runHook(root).code, 0);
});
