import {
  MissingRecaptchaSiteKeyError,
  RECAPTCHA_ACTION,
  RECAPTCHA_SITE_KEY_VARIABLE,
  RECAPTCHA_TOKEN_HEADER,
  recaptchaSiteKey,
} from "@/config/recaptcha";

describe("Bot 対策の設定", () => {
  const original = process.env;

  afterEach(() => {
    process.env = original;
  });

  it("行動の名前は、バックエンドの設定と同じです", () => {
    expect(RECAPTCHA_ACTION).toBe("generate_prompt");
  });

  it("合図は見出しで送ります", () => {
    expect(RECAPTCHA_TOKEN_HEADER).toBe("X-Recaptcha-Token");
  });

  // **サイト鍵はブラウザへ配る値です。** 秘密鍵をここへ持ちません。
  it("読む変数は NEXT_PUBLIC で始まります", () => {
    expect(RECAPTCHA_SITE_KEY_VARIABLE.startsWith("NEXT_PUBLIC_")).toBe(true);
  });

  it("鍵があれば、その値を返します", () => {
    process.env = {
      ...original,
      NEXT_PUBLIC_APP_ENV: "test",
      NEXT_PUBLIC_RECAPTCHA_SITE_KEY: "site-key-for-spec",
    };

    expect(recaptchaSiteKey()).toBe("site-key-for-spec");
  });

  // **開発とテストでは、鍵が無ければ合図を送りません。**
  it("テストでは、鍵が無ければ空を返します", () => {
    process.env = {
      ...original,
      NEXT_PUBLIC_APP_ENV: "test",
      NEXT_PUBLIC_RECAPTCHA_SITE_KEY: "",
    };

    expect(recaptchaSiteKey()).toBeNull();
  });

  // **本番では、鍵が無ければその場で失敗させます。**
  it("本番では、鍵が無ければ失敗させます", () => {
    process.env = {
      ...original,
      NEXT_PUBLIC_APP_ENV: "production",
      NEXT_PUBLIC_RECAPTCHA_SITE_KEY: "",
    };

    expect(() => recaptchaSiteKey()).toThrow(MissingRecaptchaSiteKeyError);
  });

  // **分かれ方は環境だけで決まります。** 本番で鍵があれば、その値を使います。
  it("本番でも、鍵があればその値を返します", () => {
    process.env = {
      ...original,
      NEXT_PUBLIC_APP_ENV: "production",
      NEXT_PUBLIC_RECAPTCHA_SITE_KEY: "site-key-for-spec",
    };

    expect(recaptchaSiteKey()).toBe("site-key-for-spec");
  });
});
