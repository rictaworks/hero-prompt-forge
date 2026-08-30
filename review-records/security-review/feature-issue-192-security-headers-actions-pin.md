# セキュリティレビュー : feature-issue-192-security-headers-actions-pin

- 実施日時（JST）：2026-08-31 13:00
- 差分の指紋：4dc6a9d0ea6a7329
- 対象：issue #192（release-security-gate 2026-08-31 検証レポートの検出8〜10・検出1）

## 判定

合格

## 直した弱点

| 弱点 | 影響 | 対応 |
|---|---|---|
| 本番フロントエンド（`https://hero-prompt-forge.rictaworks.jp`、Vercel配信のNext.js）にセキュリティヘッダが無かった | `Content-Security-Policy`・`X-Content-Type-Options`が無く、クリックジャッキング対策も無かったため、XSS時の被害拡大・MIMEスニッフィングによる誤解釈・iframe埋め込みによるクリックジャッキングを防ぐ手段が無かった | `next.config.ts`の`headers()`で全パスへ`Content-Security-Policy`・`X-Content-Type-Options: nosniff`・`X-Frame-Options: DENY`を付与した |
| `ci.yml`・`release-deploy.yml`のGitHub Actionsが可変タグ参照だった | アクション提供者側でタグを後から差し替えられると、レビューを経ずに任意コードがCIで実行されうる（供給網リスク） | `actions/checkout@v4`・`actions/setup-node@v4`・`ruby/setup-ruby@v1`を、取得時点の40文字コミットSHAへ固定した（バージョン注記をコメントで併記） |

## 実施した検査

| 検査 | 方法 | 結果 |
|---|---|---|
| 資格情報の混入 | 差分への正規表現検査（password / secret / api key / token / private key） | 検出なし（`SECRET_KEY_BASE: ci_boot_check_only_not_a_real_secret`は変更前から既存のプレースホルダーで、diffの文脈行として表示されただけ） |
| CSPが実際の読み込みを妨げないか | 実機確認（`npm run build` → `npm run start`、ブラウザでトップページ・`/requests/new`を開いてコンソールを確認） | CSP違反（`Refused to ...`）は0件。静的アセット（JS/CSS/フォント）は全てCSP適用状態で200 OK |
| ヘッダの実測 | `curl -sSI`で本番相当ビルドへ直接確認 | `Content-Security-Policy`・`X-Content-Type-Options: nosniff`・`X-Frame-Options: DENY`の3つとも応答に含まれることを確認 |
| 型検査・Lint・単体テスト・ビルド | `npx tsc --noEmit`・`npm run lint`・`npm test`・`npm run build` | いずれも成功（Jest 18スイート・175例・失敗0件） |
| pinしたSHAが意図したバージョンと一致するか | GitHub APIでタグ→コミットSHAの対応を確認 | `actions/checkout` `11d5960...`→`v4.4.0`、`actions/setup-node` `49933ea...`→`v4.4.0`、`ruby/setup-ruby` `95ef2b0...`→`v1`ブランチの現時点の指し先であることを確認（`v1`はバージョンタグではなく可動ブランチのため、日付を注記した） |

## あわせて把握した事項（対応は別issueとする）

- `script-src`に`'unsafe-inline'`を含めています。Next.js App Routerがハイドレーション用のインラインスクリプトをnonce無しで注入するためで、これを外すには`middleware.ts`でリクエストごとにnonceを発行し各レスポンスへ通す改修が要ります。この issue の範囲は「欠けているヘッダを足す」ことに留め、nonce化は別issueとしました
- ビルド確認時に発生した`/api/v1/session`・`/api/v1/projects`への500エラーは、確認用のdevコンテナでRailsバックエンドを起動していなかったことによるもので、この変更とは無関係です

## 指摘

指摘はありません。
