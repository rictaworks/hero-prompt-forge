/**
 * 本番で配る応答ヘッダの定義です（issue #192）。
 *
 * release-security-gate の工程E（Web動的観点確認）で、本番URL
 * （`https://hero-prompt-forge.rictaworks.jp`）への応答に以下が
 * 欠けていることを検出しました。
 *
 *   - Content-Security-Policy
 *   - X-Content-Type-Options
 *   - クリックジャッキング対策（X-Frame-Options 相当）
 *
 * **このドメインへ応答しているのは Rails ではなく、Vercel が配る
 * Next.js フロントエンドです。** ヘッダはここ（`next.config.ts`）で
 * 設定します。
 *
 * 読み込む外部リソースは reCAPTCHA（`src/lib/recaptcha.ts` が
 * `https://www.google.com/recaptcha/api.js` を読み込み、内部で
 * `www.gstatic.com` の素材と `google.com` の iframe を使います）
 * のみです。他の外部スクリプト・フレームはありません。
 *
 * **`script-src` に `'unsafe-inline'` を含みます。** Next.js の
 * App Router は、ハイドレーション用の値渡し（`__next_f` への push）を
 * nonce の無いインラインスクリプトで行うため、これを許可しないと
 * 画面が動きません。nonce 方式（`middleware.ts` でリクエストごとに
 * 発行して各レスポンスへ通す）に置き換えれば外せますが、この issue の
 * 範囲は「欠けているヘッダを足す」ことに留め、nonce化は別issueとします。
 * そのため、インラインスクリプト注入に対する防御は本ヘッダだけでは
 * 完結しません。
 */
export const SECURITY_HEADERS = [
  {
    key: "Content-Security-Policy",
    value: [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' https://www.google.com https://www.gstatic.com",
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data:",
      "font-src 'self' data:",
      "connect-src 'self' https://www.google.com https://www.gstatic.com",
      "frame-src https://www.google.com",
      "object-src 'none'",
      "base-uri 'self'",
      "form-action 'self'",
      "frame-ancestors 'none'",
    ].join('; '),
  },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  // frame-ancestors 'none'（上記CSP）と二重の防御にします。
  // CSPを解釈しない古い環境でも、この行単体でクリックジャッキングを防ぎます。
  { key: 'X-Frame-Options', value: 'DENY' },
] as const;
