# セキュリティレビュー : feature/issue-183-quota-mock-parity

- 実施日時（JST）：2026-08-29 22:16
- 差分の指紋：dcbf9a6b6f03f749
- 対象：issue #183

## 判定

合格

## 実施した検査

| 検査 | 方法 | 結果 |
|---|---|---|
| 資格情報の混入 | gitleaks 8.30.1 `protect --staged`（`~11.83 KB` を走査） | 検出なし |
| 他人の情報の露出 | 実装 | 追加した `result_prompt_request_id` は、`QuotaConsumption#user_id`（＝要求した本人）に属する識別子のみを返します。取り出し元 `Quota::Reservation.reserve!` は常に `current_user` を渡しており、他人の消費を引く経路はありません |
| 認可 | 実装 | 追加した識別子の遷移先（`GET /api/v1/prompt_requests/:id`）は既存の `owned` スコープ（`PromptRequest.for_user(current_user)`）で別途守られており、今回の変更で守りが増減する箇所はありません |
| 危険な描画（XSS） | 実装 | `status` は固定の文字列（`"confirmed"`）との厳密比較でのみ分岐に使い、値そのものを画面へ出しません。表示するのはロケールの固定文言のみです。`result_prompt_request_id` は `typeof === "number"` で検査済みの数値のみを URL の一部として使い、文字列注入の経路はありません |
| SQLインジェクション | 実装 | 追加した参照は既存の ActiveRecord のカラム参照（`consumption.status` ・ `consumption.prompt_request_id`）のみで、生SQLの追加はありません |
| 入力検証 | 実装 | 利用者から新たに受け取る入力はありません（応答へ項目を追加しただけです） |
| ログへの秘匿値出力 | 実装 | 追加箇所にログ出力はありません |
| 文言の直書き | `npm run test:hardcode` ・ `npm run check:hardcode` | 直書きの文言はありません（9例成功・走査で該当なし） |

## 指摘

指摘はありません。
