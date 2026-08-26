/**
 * バックエンドへの中継の設定です。
 *
 * **バックエンドのドメインを隠蔽します**（CLAUDE.md）。ブラウザからは
 * 画面と同じ場所（`/api/...` ・ `/auth/...`）だけが見えます。実際の
 * 呼び出し先は、Next.js の書き換え（rewrites）が**サーバー側で**解決します。
 *
 * **そのため、この値を `NEXT_PUBLIC_` で持ちません。** `NEXT_PUBLIC_` は
 * ブラウザへ配られる値ですので、隠蔽になりません。
 *
 * **未設定なら、その場で失敗させます。** 既定値へ寄せると、中継先を
 * 設定し忘れた環境で、静かに動かない画面ができます。
 */
export class MissingBackendUrlError extends Error {}

/** バックエンドの場所を読む環境変数の名前です。 */
export const BACKEND_URL_VARIABLE = "BACKEND_INTERNAL_URL";

/** 画面から見える、バックエンドへの入口です。 */
export const BACKEND_PROXY_PREFIXES = ["/api", "/auth"] as const;

/**
 * X ログインの入口です。**画面と同じ場所です。** 中継はサーバー側が行います。
 *
 * **画面の外へ出る入口です。** 画面の中の移動の仕組みを使いません
 * （先読みで、押していないのに呼ばれます）。
 */
export const LOGIN_PATH = "/auth/start";

export function backendInternalUrl(): string {
  const value = process.env[BACKEND_URL_VARIABLE];
  if (!value) {
    throw new MissingBackendUrlError(
      `${BACKEND_URL_VARIABLE} が未設定です。`, // 開発者向け
    );
  }
  return value.replace(/\/$/, "");
}

/** Next.js の書き換えの定義を組み立てます。 */
export function backendRewrites(): Array<{
  source: string;
  destination: string;
}> {
  const base = backendInternalUrl();

  return BACKEND_PROXY_PREFIXES.map((prefix) => ({
    source: `${prefix}/:path*`,
    destination: `${base}${prefix}/:path*`,
  }));
}
