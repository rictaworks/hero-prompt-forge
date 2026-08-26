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

export class RecaptchaLoadError extends Error {}

/** 読み込みは 1 回だけです。**呼ばれるたびに読み込みません。** */
let loading: Promise<Grecaptcha> | null = null;

function load(siteKey: string): Promise<Grecaptcha> {
  if (loading) {
    return loading;
  }

  loading = new Promise<Grecaptcha>((resolve, reject) => {
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

  return loading;
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

  const grecaptcha = await load(siteKey);
  const token = await grecaptcha.execute(siteKey, { action: RECAPTCHA_ACTION });
  traceInfo("recaptcha.executed", { action: RECAPTCHA_ACTION });
  return token;
}
