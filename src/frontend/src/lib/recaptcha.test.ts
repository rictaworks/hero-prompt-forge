/**
 * @jest-environment jsdom
 */
import type * as Recaptcha from "@/lib/recaptcha";

/**
 * 人の操作の合図です（PR #174 のレビュー・要修正 11）。
 *
 * **読み込みが一度失敗しても、次に押したときに取り直せます。**
 * 断られた約束を持ち続けると、画面を開き直すまで必ず失敗します。
 *
 * **持ち回しの読み直しに、本番の経路へ出す関数を使いません。**
 * `jest.resetModules()` でモジュールを丸ごと読み直し、テストごとに
 * 新しい持ち回しを得ます（PR #182 の整備より・テスト専用の抜け道を
 * 本番の束に出さないためです）。
 */
describe("人の操作の合図", () => {
  const original = process.env;
  let humanToken: typeof Recaptcha.humanToken;
  let RecaptchaLoadError: typeof Recaptcha.RecaptchaLoadError;

  beforeEach(() => {
    jest.resetModules();
    // eslint-disable-next-line @typescript-eslint/no-require-imports -- モジュールを丸ごと読み直すためです。
    ({ humanToken, RecaptchaLoadError } = require("@/lib/recaptcha") as typeof Recaptcha);
    document.head.innerHTML = "";
    delete window.grecaptcha;
  });

  afterEach(() => {
    process.env = original;
  });

  function withKey(key: string) {
    process.env = {
      ...original,
      NEXT_PUBLIC_APP_ENV: "test",
      NEXT_PUBLIC_RECAPTCHA_SITE_KEY: key,
    };
  }

  /** 読み込みの結果を決めます。 */
  function settle(succeeds: boolean) {
    const script = document.head.querySelector("script");
    if (!script) {
      throw new Error("読み込みが始まっていません。"); // 開発者向け
    }
    if (!succeeds) {
      script.onerror?.(new Event("error"));
      return;
    }
    window.grecaptcha = {
      ready: (callback: () => void) => callback(),
      execute: () => Promise.resolve("token-for-spec"),
    };
    script.onload?.(new Event("load"));
  }

  // **鍵が無ければ、合図を送りません。**
  it("鍵が無ければ、合図を送りません", async () => {
    withKey("");

    await expect(humanToken()).resolves.toBeNull();
  });

  it("鍵が無ければ、読み込みもしません", async () => {
    withKey("");

    await humanToken();

    expect(document.head.querySelector("script")).toBeNull();
  });

  it("鍵があれば、合図を返します", async () => {
    withKey("site-key");
    const pending = humanToken();
    settle(true);

    await expect(pending).resolves.toBe("token-for-spec");
  });

  it("読み込みは 1 回だけです", async () => {
    withKey("site-key");
    const first = humanToken();
    settle(true);
    await first;

    await humanToken();

    expect(document.head.querySelectorAll("script")).toHaveLength(1);
  });

  it("読み込みに失敗すれば、失敗をそのまま伝えます", async () => {
    withKey("site-key");
    const pending = humanToken();
    settle(false);

    await expect(pending).rejects.toThrow(RecaptchaLoadError);
  });

  // **一度の失敗で、二度と送れなくなりません。**
  it("失敗しても、次に押したときに取り直します", async () => {
    withKey("site-key");
    const failing = humanToken();
    settle(false);
    await expect(failing).rejects.toThrow(RecaptchaLoadError);
    document.head.innerHTML = "";

    const retried = humanToken();
    settle(true);

    await expect(retried).resolves.toBe("token-for-spec");
  });
});
