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
  fullyParallel: true,
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
