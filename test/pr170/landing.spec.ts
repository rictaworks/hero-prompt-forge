import { expect, test } from "@playwright/test";

/**
 * ランディング（01）の確認です（issue #69、PR #170）。
 *
 * PR 本文の非エンジニア向けユーザーテスト手順と 1 対 1 で対応させます。
 * **手順に無い操作を足しません。**
 */
test.describe("ランディング", () => {
  /**
   * **読み込みの完了を待ちません。**
   *
   * 既定の待ち方（`load`）は、すべての資源が届くまで待ちます。ヒーローの
   * 写真は、はじめて開いたときに大きさを整える処理が走りますので、**温まって
   * いない開発サーバーでは間に合いません**（PR #170 のレビューで実測されました）。
   *
   * **確かめるのは文書の中身です。** 文書が組み上がった時点で、見出しも
   * ログインの入口も読めます。**写真の到着を待つ必要がありません。**
   */
  test.beforeEach(async ({ page }) => {
    await page.goto("/", { waitUntil: "domcontentloaded" });
  });

  // 手順 1：見出しが出ること
  test("大きな見出しが出ます", async ({ page }) => {
    await expect(
      page.getByRole("heading", { level: 1, name: /Forge Heroes/ }),
    ).toBeVisible();
  });

  // 手順 2：ログインの入口が 3 か所にあること
  test("ログインの入口があります", async ({ page }) => {
    await expect(page.getByRole("link", { name: /Xでログイン/ })).toHaveCount(3);
  });

  // 手順 3：ログインの入口が、画面と同じ場所を指すこと
  // **バックエンドの場所が画面へ出ていないことの確認です。**
  test("ログインの入口は画面と同じ場所を指します", async ({ page }) => {
    const links = page.getByRole("link", { name: /Xでログイン/ });

    for (const link of await links.all()) {
      await expect(link).toHaveAttribute("href", "/auth/start");
    }
  });

  // 手順 4：3 つの規則が並ぶこと
  test("3 つの規則が並びます", async ({ page }) => {
    await expect(page.getByRole("heading", { name: "Anti-Cliché Rules" })).toBeVisible();
    await expect(page.getByRole("heading", { name: "Photographic Spec" })).toBeVisible();
    await expect(page.getByRole("heading", { name: "Copy Space Guard" })).toBeVisible();
  });

  // 手順 5：4 つの手順が並ぶこと
  test("4 つの手順が並びます", async ({ page }) => {
    // **完全一致で探します。** 「From Input to Package」が「Input」を
    // 含むため、部分一致では 2 件に当たります。
    for (const title of ["Input", "Rules", "Refine", "Package"]) {
      await expect(
        page.getByRole("heading", { name: title, exact: true }),
      ).toBeVisible();
    }
  });

  // 手順 6：よくある質問が開くこと
  test("よくある質問は、はじめは閉じています", async ({ page }) => {
    const question = page.getByRole("button", { name: /生成された画像も/ });

    await expect(question).toHaveAttribute("aria-expanded", "false");
  });

  test("よくある質問を押すと開きます", async ({ page }) => {
    const question = page.getByRole("button", { name: /生成された画像も/ });

    await question.click();

    await expect(question).toHaveAttribute("aria-expanded", "true");
  });

  // 手順 7：画面の中の移動ができること
  test("画面の中を移動できます", async ({ page }) => {
    await page.getByRole("link", { name: "Features" }).click();

    await expect(page).toHaveURL(/#features$/);
  });

  // 手順 8：狭い画面でも横へはみ出さないこと
  test("狭い画面でも横へはみ出しません", async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });

    const overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );

    expect(overflow).toBeLessThanOrEqual(1);
  });
});
