import { defineConfig, devices } from "@playwright/test";

/**
 * ブラウザ操作による確認の設定です。
 *
 * - テストは src の外（test/pr<番号>/）に置きます。
 * - 対象は開発サーバーです。本番環境に対して実行しません。
 * - 接続先は環境変数から読みます。既定値へ寄せず、未設定なら失敗させます。
 */
const baseURL = process.env.E2E_BASE_URL;

if (!baseURL) {
  throw new Error(
    "E2E_BASE_URL が未設定です。開発サーバーの URL を .env に設定してください。",
  );
}

if (!/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?/.test(baseURL)) {
  throw new Error(
    `E2E_BASE_URL が開発サーバーを指していません: ${baseURL}。本番環境に対してテストを実行しません。`,
  );
}

export default defineConfig({
  testDir: "./test",
  testMatch: "**/pr*/**/*.spec.ts",
  /**
   * **1 つずつ流します。**
   *
   * 確認の相手は、**1 台の開発サーバーと 1 つのアカウント**です。
   * そのアカウントの生成の枠は **1 日 1 回**で（requirements.md 4.4）、
   * 保存したプロジェクト・プリセット・評価メモも、すべての例で共有されます。
   * **例ごとに分けられない資源です。**
   *
   * 並べて流すと、枠を使い切る前の要求と後の要求が入れ替わり、どちらの結果も
   * 定まりません（PR #174 のレビュー・要修正 8）。**設定と実際の流し方を
   * 一致させます。** 「設定どおりに流すと落ちる」状態を残しません。
   *
   * **速さより、結果が毎回同じであることを採ります。**
   */
  fullyParallel: false,
  workers: 1,
  forbidOnly: !!process.env.CI,
  retries: 0,
  reporter: [["list"]],
  use: {
    baseURL,
    trace: "on-first-retry",
    locale: "ja-JP",
    timezoneId: "Asia/Tokyo",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
