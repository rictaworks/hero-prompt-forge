import { expect, test } from "@playwright/test";

/**
 * ブラウザ操作の基盤が動くことだけを確かめます。
 * 画面がまだ無いため、外部へ接続せずブラウザ自体の動作を確認します。
 * 画面ができ次第、PR 本文のユーザーテスト手順と1対1で対応する spec を
 * test/pr<PR番号>/ に置きます。
 */
test("ブラウザが起動し、日本語を表示できます", async ({ page }) => {
  await page.setContent(
    "<html lang='ja'><body><h1>動作確認</h1></body></html>",
  );

  await expect(page.getByRole("heading", { name: "動作確認" })).toBeVisible();
});

test("表示の設定が日本語・日本時間になっています", async ({ page }) => {
  await page.setContent("<html lang='ja'><body></body></html>");

  const locale = await page.evaluate(() => navigator.language);
  const timeZone = await page.evaluate(
    () => Intl.DateTimeFormat().resolvedOptions().timeZone,
  );

  expect(locale).toBe("ja-JP");
  expect(timeZone).toBe("Asia/Tokyo");
});
