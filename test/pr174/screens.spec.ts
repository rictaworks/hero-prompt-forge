import { expect, test } from "@playwright/test";

/**
 * 履歴・一覧から評価メモまでの確認です（issue #70 ・ #71 ・ #152 ・ #72 ・ #73 ・
 * #74 ・ #75 ・ #76 ・ #77、PR #174）。
 *
 * PR 本文の非エンジニア向けユーザーテスト手順と 1 対 1 で対応させます。
 * **手順に無い操作を足しません。**
 *
 * **読み込みの完了を待ちません。** 写真の到着を待つ必要がありません
 * （PR #170 のレビューより）。
 */

/** 開発環境では、認証済みへ分岐します（`AuthenticatesUser`）。 */
async function open(page: import("@playwright/test").Page, path: string) {
  await page.goto(path, { waitUntil: "domcontentloaded" });
}

test.describe("履歴・一覧（02）", () => {
  // 手順 1：一覧が開くこと
  test("見出しが出ます", async ({ page }) => {
    await open(page, "/projects");

    await expect(
      page.getByRole("heading", { name: "Projects & Requests" }),
    ).toBeVisible();
  });

  // 手順 2：上部バーに管理の導線が出ないこと（issue #77）
  test("管理への導線が出ません", async ({ page }) => {
    await open(page, "/projects");

    await expect(page.getByText("Admin", { exact: true })).toHaveCount(0);
    await expect(page.getByText("管理", { exact: true })).toHaveCount(0);
  });

  // 手順 3：新規生成の入口があること
  test("新規生成の入口があります", async ({ page }) => {
    await open(page, "/projects");

    await expect(page.getByRole("link", { name: "新規生成" })).toHaveAttribute(
      "href",
      "/requests/new",
    );
  });

  // 手順 4：過去の生成が一覧に出ること
  test("過去の生成が並びます", async ({ page }) => {
    await open(page, "/projects");

    await expect(page.getByRole("link", { name: "開く" }).first()).toBeVisible();
  });

  // 手順 5：縮退の印が一覧に出ること
  test("縮退の印が出ます", async ({ page }) => {
    await open(page, "/projects");

    await expect(page.getByText("縮退", { exact: true }).first()).toBeVisible();
  });
});

test.describe("入力フォーム（03）", () => {
  test.beforeEach(async ({ page }) => {
    await open(page, "/requests/new");
  });

  // 手順 6：必須の 3 項目が並ぶこと
  test("必須の 3 項目が並びます", async ({ page }) => {
    await expect(page.getByLabel(/業種/)).toBeVisible();
    await expect(page.getByLabel(/スタイル系統/)).toBeVisible();
    await expect(page.getByLabel(/生成モデル/)).toBeVisible();
  });

  // 手順 7：未入力のまま送ると、画面で止まること（issue #71）
  test("未入力のまま送ると画面で止まります", async ({ page }) => {
    await page.getByRole("button", { name: "3 案を生成" }).click();

    await expect(page.getByText("業種を選んでください。")).toBeVisible();
    await expect(page.getByText("スタイル系統を選んでください。")).toBeVisible();
    await expect(page.getByText("生成モデルを選んでください。")).toBeVisible();
    await expect(page).toHaveURL(/\/requests\/new$/);
  });

  // 手順 8：お名前の書き方の案内が、例 3 つとともに出ること（issue #152）
  test("お名前の書き方の案内が出ます", async ({ page }) => {
    await expect(page.getByText("名前を確実に反映させる書き方")).toBeVisible();
    await expect(page.getByText(/さくら堂/)).toBeVisible();
    await expect(page.getByText(/櫻花堂/)).toBeVisible();
    await expect(page.getByText(/ミライ工房/)).toBeVisible();
  });

  // 手順 9：ネイティブの警告表示を使わないこと
  test("ネイティブの警告表示を出しません", async ({ page }) => {
    let opened = false;
    page.on("dialog", (dialog) => {
      opened = true;
      return dialog.dismiss();
    });

    await page.getByRole("button", { name: "3 案を生成" }).click();
    await expect(page.getByText("業種を選んでください。")).toBeVisible();

    expect(opened).toBe(false);
  });
});

test.describe("生成中・縮退（04・08）", () => {
  // 手順 10：状態が出ること
  test("状態が出ます", async ({ page }) => {
    await open(page, "/requests/1");

    await expect(page.getByRole("heading", { name: "Generating" })).toBeVisible();
    await expect(page.getByText("MODEL", { exact: true })).toBeVisible();
  });

  // 手順 11：縮退の帯が出ること（issue #76）
  test("縮退の帯が出ます", async ({ page }) => {
    await open(page, "/requests/1");

    await expect(page.getByText("DEGRADED MODE")).toBeVisible();
    await expect(page.getByText("NOT REFINED")).toBeVisible();
  });

  // 手順 12：3 案へ進めること
  test("3 案へ進めます", async ({ page }) => {
    await open(page, "/requests/1");

    await page.getByRole("link", { name: "3 案を見る" }).click();

    await expect(page).toHaveURL(/\/requests\/1\/result$/);
  });
});

test.describe("結果 3 案（05）", () => {
  test.beforeEach(async ({ page }) => {
    await open(page, "/requests/1/result");
  });

  // 手順 13：3 案が構図の別とともに出ること
  test("3 案が構図の別とともに出ます", async ({ page }) => {
    await expect(page.getByRole("heading", { name: "被写体主導" })).toBeVisible();
    await expect(page.getByRole("heading", { name: "環境主導" })).toBeVisible();
    await expect(page.getByRole("heading", { name: "抽象背景" })).toBeVisible();
  });

  // 手順 14：コピーの操作があること
  test("コピーの操作があります", async ({ page }) => {
    await expect(page.getByRole("button", { name: "コピー" }).first()).toBeVisible();
  });

  // 手順 15：縮退の印が案ごとに出ること
  test("縮退の印が案ごとに出ます", async ({ page }) => {
    await expect(page.getByText("NOT REFINED")).toHaveCount(3);
  });

  // 手順 16：アートディレクションノートが出ること
  test("アートディレクションノートが出ます", async ({ page }) => {
    await expect(
      page.getByText("出来上がった絵で確かめること").first(),
    ).toBeVisible();
  });
});

test.describe("評価メモ（06）", () => {
  // 手順 17：評価メモを記録できること（issue #74）
  test("評価メモを記録できます", async ({ page }) => {
    await open(page, "/requests/1/notes");

    const memo = page.getByLabel("所感").first();
    await memo.fill("余白が読みやすいです。");
    await page.getByRole("button", { name: "この案のメモを保存" }).first().click();

    await expect(
      page.getByRole("button", { name: "保存済み" }).first(),
    ).toBeVisible();
  });

  // 手順 18：記録が残ること
  //
  // **この例だけで完結させます。** 前の例が保存した内容を読むと、
  // 並べて動かしたときに順番が入れ替わって落ちます
  // （PR #174 の整備で実測されました）。
  test("記録が残ります", async ({ page }) => {
    const written = `余白が読みやすいです。${Date.now()}`;

    await open(page, "/requests/1/notes");
    await page.getByLabel("所感").first().fill(written);
    await page.getByRole("button", { name: "この案のメモを保存" }).first().click();
    await expect(
      page.getByRole("button", { name: "保存済み" }).first(),
    ).toBeVisible();

    await open(page, "/requests/1/notes");

    await expect(page.getByLabel("所感").first()).toHaveValue(written);
  });
});

test.describe("プリセット（07）", () => {
  // 手順 19：プリセットの画面が開くこと
  test("見出しが出ます", async ({ page }) => {
    await open(page, "/presets");

    await expect(
      page.getByRole("heading", { name: "Saved Conditions" }),
    ).toBeVisible();
  });

  // 手順 20：入力フォームから保存できること（issue #75）
  //
  // **名前は利用者ごとに一意です**（`SPEC/api/README.md`）。同じ名前で
  // 二度保存すると断られますので、**そのつど違う名前を使います。**
  test("いまの条件を保存できます", async ({ page }) => {
    await open(page, "/requests/new");

    await page.getByLabel(/業種/).selectOption("saas");
    await page.getByLabel(/スタイル系統/).selectOption("photoreal");
    await page.getByLabel(/生成モデル/).selectOption("midjourney");
    await page.getByLabel("プリセット名").fill(`定番 ${Date.now()}`);
    await page.getByRole("button", { name: "いまの条件を保存" }).click();

    await expect(page.getByText("プリセットを保存しました。")).toBeVisible();
  });

  // 手順 21：保存した条件を入力フォームへ呼び出せること
  test("保存した条件を入力フォームへ呼び出せます", async ({ page }) => {
    await open(page, "/presets");

    await page.getByRole("link", { name: "この条件で作る" }).first().click();

    await expect(page).toHaveURL(/\/requests\/new\?preset_id=\d+$/);
    await expect(page.getByLabel(/業種/)).toHaveValue("saas");
    await expect(page.getByLabel(/生成モデル/)).toHaveValue("midjourney");
  });
});

test.describe("狭い画面", () => {
  // 手順 22：狭い画面でも横へはみ出さないこと
  for (const path of ["/projects", "/requests/new", "/requests/1/result"]) {
    test(`狭い画面でも横へはみ出しません（${path}）`, async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 812 });
      await open(page, path);

      const overflow = await page.evaluate(
        () =>
          document.documentElement.scrollWidth -
          document.documentElement.clientWidth,
      );

      expect(overflow).toBeLessThanOrEqual(1);
    });
  }
});
