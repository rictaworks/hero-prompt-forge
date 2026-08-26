/**
 * 画面の公開先です。
 *
 * **共有されたときの見え方（OGP）と、正となる場所（canonical）に使います。**
 * 相対の場所だけでは、共有先が絵や説明を引けません。
 *
 * **未設定なら、その場で失敗させます。** 既定値へ寄せると、共有されたときに
 * 誤った場所を指したまま気づけません。
 */
export class MissingPublicBaseUrlError extends Error {}

/** 公開先を読む環境変数の名前です。**ブラウザへ配ってよい値です。** */
export const PUBLIC_BASE_URL_VARIABLE = "NEXT_PUBLIC_BASE_URL";

export function publicBaseUrl(): string {
  const value = process.env[PUBLIC_BASE_URL_VARIABLE];
  if (!value) {
    throw new MissingPublicBaseUrlError(
      `${PUBLIC_BASE_URL_VARIABLE} が未設定です。`, // 開発者向け
    );
  }
  return value.replace(/\/$/, "");
}
