/**
 * Bot 対策（reCAPTCHA v3）の設定です（requirements.md 5.2、issue #61）。
 *
 * **サイト鍵はブラウザへ配る値です。** 秘密鍵は画面が持ちません。照合は
 * バックエンドが行います。
 *
 * **本番では、鍵が無ければその場で失敗させます。** 鍵の入れ忘れで
 * Bot 対策が黙って無効になる状態を作りません。
 *
 * **開発とテストでは、鍵が無ければ合図を送りません。** バックエンドも、
 * 鍵が設定されているときだけ照合します（`VerifiesHumans`）。**この分かれ方は
 * 環境だけで決まります。** 画面の値では切り替わりません。
 */
import { isProduction } from "@/config/environment";

export class MissingRecaptchaSiteKeyError extends Error {}

/** サイト鍵を読む環境変数の名前です。**ブラウザへ配ってよい値です。** */
export const RECAPTCHA_SITE_KEY_VARIABLE = "NEXT_PUBLIC_RECAPTCHA_SITE_KEY";

/** 求める行動の名前です。**バックエンドの `config/recaptcha.yml` と同じ名前です。** */
export const RECAPTCHA_ACTION = "generate_prompt";

/** 合図を載せる見出しです。**本文へ混ぜません。** */
export const RECAPTCHA_TOKEN_HEADER = "X-Recaptcha-Token";

/**
 * サイト鍵を返します。**開発とテストでは、未設定なら `null` です。**
 * 本番では、未設定はその場で失敗します。
 */
export function recaptchaSiteKey(): string | null {
  const value = process.env.NEXT_PUBLIC_RECAPTCHA_SITE_KEY;
  if (value) {
    return value;
  }
  if (isProduction()) {
    throw new MissingRecaptchaSiteKeyError(
      `${RECAPTCHA_SITE_KEY_VARIABLE} が未設定です。`, // 開発者向け
    );
  }
  return null;
}
