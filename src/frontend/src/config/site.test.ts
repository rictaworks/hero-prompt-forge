import { describe, expect, it, afterEach } from "@jest/globals";
import {
  MissingPublicBaseUrlError,
  PUBLIC_BASE_URL_VARIABLE,
  publicBaseUrl,
} from "@/config/site";

describe("画面の公開先", () => {
  const original = process.env[PUBLIC_BASE_URL_VARIABLE];

  afterEach(() => {
    if (original === undefined) {
      delete process.env[PUBLIC_BASE_URL_VARIABLE];
    } else {
      process.env[PUBLIC_BASE_URL_VARIABLE] = original;
    }
  });

  // **既定値へ寄せません。** 誤った場所を指したまま気づけません。
  it("未設定なら失敗させます", () => {
    delete process.env[PUBLIC_BASE_URL_VARIABLE];

    expect(() => publicBaseUrl()).toThrow(MissingPublicBaseUrlError);
  });

  it("末尾の区切りを落とします", () => {
    process.env[PUBLIC_BASE_URL_VARIABLE] = "https://forge.example.jp/";

    expect(publicBaseUrl()).toBe("https://forge.example.jp");
  });

  // **これはブラウザへ配ってよい値です。** 隠す必要がありません。
  it("公開される変数の名前です", () => {
    expect(PUBLIC_BASE_URL_VARIABLE.startsWith("NEXT_PUBLIC_")).toBe(true);
  });
});
