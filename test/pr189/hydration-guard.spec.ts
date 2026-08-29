import { expect, test } from "@playwright/test";

/**
 * 組み上がる前の送信保護です（issue #184）。
 *
 * **実測された不具合**：入力フォーム（03）で、画面が組み上がる前
 * （JavaScript の読み込みが終わる前）に送信ボタンが押されると、
 * `onSubmit` がまだ付いていないため、ブラウザの既定の動き（素の GET 送信）が
 * 起き、`/requests/new?...` へ遷移して入力していただいた内容が消えます。
 *
 * **組み上がりの速さに左右されない形で確かめます。** ネットワークを遅らせて
 * 「組み上がる前」の一瞬を狙う方法は、開発サーバー（`npm run dev`）と
 * 本番相当の組み立て（`npm run start`）とで組み上がる速さが大きく違い、
 * 安定して捕まえられませんでした（実測）。**代わりに、`domcontentloaded`
 * 直後という最も早いタイミングで、実際にボタンへ素のクリックを送り込み、
 * その結果として `?` を含む URL へ遷移しないことを確かめます。** ボタンが
 * まだ描かれていなければクリックは何も起こさず、描かれていれば
 * `disabled` かどうかに関わらず、この確認がそのまま結果を保証します。
 */
test.describe("入力フォーム（03）・組み上がる前の送信保護", () => {
  // 手順 1：もっとも早いタイミングで送信ボタンへクリックを送っても、
  // 素の GET 送信（`?` 付きの URL への遷移）が起きないこと
  test("もっとも早いタイミングで押しても、素の GET 送信は起きません", async ({
    page,
  }) => {
    await page.goto("/requests/new", { waitUntil: "domcontentloaded" });

    // **Playwright の待ち合わせを経由しません。** 通常の `click()` は要素が
    // 押せる状態になるまで自動で待つため、この確認の意味がなくなります。
    await page.evaluate(() => {
      document
        .querySelector<HTMLButtonElement>('button[type="submit"]')
        ?.click();
    });

    // 素の GET 送信が起きていれば、この間にページ全体の遷移が終わります。
    await page.waitForLoadState("networkidle").catch(() => undefined);

    await expect(page).toHaveURL(/\/requests\/new$/);
  });

  // 手順 2：組み上がれば、送信ボタンが押せるようになること
  test("組み上がれば、送信ボタンが押せるようになります", async ({ page }) => {
    await page.goto("/requests/new", { waitUntil: "domcontentloaded" });

    await expect(
      page.getByRole("button", { name: "3 案を生成" }),
    ).toBeEnabled({ timeout: 10000 });
  });

  // 手順 3：組み上がったあとは、これまでどおり送信できること（回帰の確認）
  test("組み上がったあとは、これまでどおり画面で止まります", async ({ page }) => {
    await page.goto("/requests/new", { waitUntil: "domcontentloaded" });

    await page.getByRole("button", { name: "3 案を生成" }).click();

    await expect(page.getByText("業種を選んでください。")).toBeVisible();
    await expect(page).toHaveURL(/\/requests\/new$/);
  });
});
