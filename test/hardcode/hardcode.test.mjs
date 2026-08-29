import assert from "node:assert/strict";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

import { scan } from "./check-hardcoded-strings.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const fixtures = join(here, "fixtures");

test("直書きの文言を検出します", () => {
  const violations = scan(fixtures);
  const files = violations.map((v) => v.file.replaceAll("\\", "/"));

  assert.ok(files.includes("src/frontend/src/components/Ng.tsx"));
  assert.ok(files.includes("src/backend/app/models/ng.rb"));
});

test("文言の置き場所は検出しません", () => {
  const files = scan(fixtures).map((v) => v.file.replaceAll("\\", "/"));

  assert.ok(!files.some((f) => f.includes("strings/")));
  assert.ok(!files.some((f) => f.includes("locales/")));
});

test("コメントと関数呼び出しは検出しません", () => {
  const files = scan(fixtures).map((v) => v.file.replaceAll("\\", "/"));

  assert.ok(!files.includes("src/frontend/src/components/Ok.tsx"));
});

// **画面の雛形も検査の対象です**（PR #175 のレビュー・要修正 3）。
// 見本を置かないと、対象から `.erb` を外しても検査が緑のままです。
// **せっかく広げた検査が、黙って元へ戻せます**（issue #177 の提案 11）。
test("画面の雛形の直書きを検出します", () => {
  const files = scan(fixtures).map((v) => v.file.replaceAll("\\", "/"));

  assert.ok(files.includes("src/backend/app/views/admin/ng.html.erb"));
});

// **タグの属性の中の文言も直書きです**（issue #177 の提案 12）。
// 地の文だけを見ると、`alt` や `title` の日本語が素通りします。
test("雛形の属性の中の文言を検出します", () => {
  const literals = scan(fixtures)
    .filter((v) => v.file.replaceAll("\\", "/") === "src/backend/app/views/admin/ng.html.erb")
    .map((v) => v.literal);

  assert.ok(literals.includes("直書きの代替文です"));
  assert.ok(literals.includes("直書きの見出しです"));
});

// **一重引用符の属性も検出します**（PR #182 のレビューより）。
// 見本が二重引用符しか使わないと、一重引用符の側だけを検査から落としても
// 気づけません。
test("一重引用符の属性の中の文言も検出します", () => {
  const literals = scan(fixtures)
    .filter((v) => v.file.replaceAll("\\", "/") === "src/backend/app/views/admin/ng.html.erb")
    .map((v) => v.literal);

  assert.ok(literals.includes("一重引用符の直書きです"));
});

test("雛形の注記と文言の呼び出しは検出しません", () => {
  const files = scan(fixtures).map((v) => v.file.replaceAll("\\", "/"));

  assert.ok(!files.includes("src/backend/app/views/admin/ok.html.erb"));
});

test("検出した件数は5件です", () => {
  assert.equal(scan(fixtures).length, 5);
});

test("開発者向けの印が付いた行は検出しません", () => {
  const files = scan(fixtures).map((v) => v.file.replaceAll("\\", "/"));

  assert.ok(!files.includes("src/backend/app/models/developer_only.rb"));
});
