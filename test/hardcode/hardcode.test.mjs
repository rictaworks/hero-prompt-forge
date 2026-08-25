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

test("検出した件数は2件です", () => {
  assert.equal(scan(fixtures).length, 2);
});

test("開発者向けの印が付いた行は検出しません", () => {
  const files = scan(fixtures).map((v) => v.file.replaceAll("\\", "/"));

  assert.ok(!files.includes("src/backend/app/models/developer_only.rb"));
});
