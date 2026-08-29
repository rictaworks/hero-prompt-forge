import { expect, test } from "@playwright/test";

/**
 * 組み上がる前の送信保護です（issue #184）。
 *
 * **実測された不具合**：入力フォーム（03）で、画面が組み上がる前
 * （JavaScript の読み込みが終わる前）に送信ボタンが押されると、
 * `onSubmit` がまだ付いていないため、ブラウザの既定の動き（素の GET 送信）が
 * 起き、`/requests/new?...` へ遷移して入力していただいた内容が消えます。
 *
 * **組み上がる前の状態を、意図的に作ります。** `_next` の静的資産（JS・CSS）を
 * 遅らせ、HTML の到着とスクリプトの実行の間に間を空けます。
 */
async function delayHydration(page: import("@playwright/test").Page, ms: number) {
  await page.route("**/_next/**", async (route) => {
    await new Promise((resolve) => setTimeout(resolve, ms));
    await route.continue();
  });
}

test.describe("入力フォーム（03）・組み上がる前の送信保護", () => {
  // 手順 1：組み上がる前は、送信ボタンが押せないこと
  test("組み上がる前は、送信ボタンが押せません", async ({ page }) => {
    await delayHydration(page, 1500);

    await page.goto("/requests/new", { waitUntil: "domcontentloaded" });

    await expect(
      page.getByRole("button", { name: "3 案を生成" }),
    ).toBeDisabled();
  });

  // 手順 2：組み上がれば、送信ボタンが押せるようになること
  test("組み上がれば、送信ボタンが押せるようになります", async ({ page }) => {
    await delayHydration(page, 1500);

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
