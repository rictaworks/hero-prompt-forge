"use client";

import { RECAPTCHA_ACTION, recaptchaSiteKey } from "@/config/recaptcha";
import { traceInfo } from "@/lib/logger";

/**
 * 人の操作であることの合図（reCAPTCHA v3）を取ります。
 *
 * **Bot 対策を自作しません**（CLAUDE.md）。判定は Google に委ねます。
 *
 * **読み込みは、投入する画面でだけ行います。** 画面を移るたびに第三者へ
 * 問い合わせません（`SPEC/api/README.md`）。
 *
 * **失敗を握りつぶしません。** 合図を取れなければ、そのまま投げます。
 * 合図の無いまま投入すると、本番では断られます。
 */

/** Google が読み込む配布元です。 */
const SCRIPT_ORIGIN = "https://www.google.com/recaptcha/api.js";

interface Grecaptcha {
  ready(callback: () => void): void;
  execute(siteKey: string, options: { action: string }): Promise<string>;
}

declare global {
  interface Window {
    grecaptcha?: Grecaptcha;
  }
}

export type { Grecaptcha };

export class RecaptchaLoadError extends Error {}

/**
 * 読み込みの持ち回しです。
 *
 * **読み込みは 1 回だけです。** 呼ばれるたびに読み込みません。
 *
 * **失敗したら、持ち回しを解きます**（PR #174 のレビュー・要修正 11）。
 * 断られた約束を持ち続けると、通信が一度でも失敗したときに、**以降の投入が
 * 画面を開き直すまで必ず失敗します。** 利用者から見ると「何度押しても
 * 送れない」状態になります。
 *
 * **書き換わる値を、そのまま外へ置きません**（CLAUDE.md）。
 * 持ち回しはこの入れ物の中だけにあります。
 */
class Loader {
  private loading: Promise<Grecaptcha> | null = null;

  load(siteKey: string): Promise<Grecaptcha> {
    if (this.loading) {
      return this.loading;
    }

    const started = this.start(siteKey).catch((cause: unknown) => {
      // **次に押したときに、取り直せるようにします。**
      this.loading = null;
      throw cause;
    });

    this.loading = started;
    return started;
  }

  private start(siteKey: string): Promise<Grecaptcha> {
    return new Promise<Grecaptcha>((resolve, reject) => {
      const script = document.createElement("script");
      script.src = `${SCRIPT_ORIGIN}?render=${encodeURIComponent(siteKey)}`;
      script.async = true;
      script.onload = () => {
        const grecaptcha = window.grecaptcha;
        if (!grecaptcha) {
          reject(new RecaptchaLoadError("reCAPTCHA を読み込めませんでした。")); // 開発者向け
          return;
        }
        grecaptcha.ready(() => resolve(grecaptcha));
      };
      script.onerror = () =>
        reject(new RecaptchaLoadError("reCAPTCHA の読み込みに失敗しました。")); // 開発者向け
      document.head.appendChild(script);
    });
  }
}

const loader = new Loader();

/** テストから読み直せるようにします。**本番の経路では使いません。** */
export function resetLoader(): void {
  Object.assign(loader, new Loader());
}

/**
 * 合図を返します。**鍵が無い環境では `null` です。**
 *
 * 本番で鍵が無い場合は `MissingRecaptchaSiteKeyError` になります。
 */
export async function humanToken(): Promise<string | null> {
  const siteKey = recaptchaSiteKey();
  if (siteKey === null) {
    traceInfo("recaptcha.skipped");
    return null;
  }

  const grecaptcha = await loader.load(siteKey);
  const token = await grecaptcha.execute(siteKey, { action: RECAPTCHA_ACTION });
  traceInfo("recaptcha.executed", { action: RECAPTCHA_ACTION });
  return token;
}
