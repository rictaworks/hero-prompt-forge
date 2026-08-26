import { describe, expect, it, afterEach } from "@jest/globals";
import {
  BACKEND_URL_VARIABLE,
  MissingBackendUrlError,
  backendInternalUrl,
  backendRewrites,
} from "@/config/backend";

describe("バックエンドへの中継", () => {
  const original = process.env[BACKEND_URL_VARIABLE];

  afterEach(() => {
    if (original === undefined) {
      delete process.env[BACKEND_URL_VARIABLE];
    } else {
      process.env[BACKEND_URL_VARIABLE] = original;
    }
  });

  // **既定値へ寄せません。** 設定し忘れた環境で静かに動かない画面を作りません。
  it("未設定なら失敗させます", () => {
    delete process.env[BACKEND_URL_VARIABLE];

    expect(() => backendInternalUrl()).toThrow(MissingBackendUrlError);
  });

  it("末尾の区切りを落とします", () => {
    process.env[BACKEND_URL_VARIABLE] = "http://api:3000/";

    expect(backendInternalUrl()).toBe("http://api:3000");
  });

  // **ブラウザへ配る値に、バックエンドの場所を入れません。**
  it("公開される変数の名前ではありません", () => {
    expect(BACKEND_URL_VARIABLE.startsWith("NEXT_PUBLIC_")).toBe(false);
  });

  it("入口ごとに書き換えを作ります", () => {
    process.env[BACKEND_URL_VARIABLE] = "http://api:3000";

    expect(backendRewrites()).toEqual([
      { source: "/api/:path*", destination: "http://api:3000/api/:path*" },
      { source: "/auth/:path*", destination: "http://api:3000/auth/:path*" },
    ]);
  });
});
