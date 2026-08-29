import { expect, test } from "@playwright/test";

/**
 * 組み上がる前の送信保護です（issue #184）。
 *
 * **実測された不具合**：入力フォーム（03）で、画面が組み上がる前
 * （JavaScript の読み込みが終わる前）に送信ボタンが押されると、
 * `onSubmit` がまだ付いていないため、ブラウザの既定の動き（素の GET 送信）が
 * 起き、`/requests/new?...` へ遷移して入力していただいた内容が消えます。
 *
 * **ネットワークの遅延で「組み上がる前」を再現しません。** JS の読み込みを
 * 遅らせて狙う方法は、CI（本番と同じ組み立て）と手元の開発サーバーとで
 * 読み込みの速さが違い、狙った瞬間を安定して捕まえられませんでした
 * （実測：手元では捕まえられても、CI では組み上がりが速く、5 秒の間ずっと
 * 押せる状態のままでした）。**サーバーが描いた HTML そのもの**を確かめれば、
 * JavaScript がまったく動いていない状態（＝組み上がる前のどの瞬間でも）で
 * ボタンが押せないことを、タイミングに左右されずに確かめられます。
 */
test.describe("入力フォーム（03）・組み上がる前の送信保護", () => {
  // 手順 1：サーバーが描いた時点の HTML に、送信ボタンの disabled が
  // 含まれていること（＝ JavaScript が 1 行も動く前から押せません）
  test("サーバーが描いた HTML の時点で、送信ボタンは押せない形になっています", async ({
    page,
    baseURL,
  }) => {
    const response = await page.request.get(`${baseURL}/requests/new`);
    const html = await response.text();

    // **この画面の `type="submit"` は、送信ボタン 1 つだけです。** 他のボタン
    // （プリセット保存・入力を修正する 等）は `type="button"` か、初期表示では
    // 描かれません。
    const button = html.match(/<button[^>]*type="submit"[^>]*>/);

    expect(button).not.toBeNull();
    expect(button?.[0]).toMatch(/\bdisabled(="{2}|\s|>)/);
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
