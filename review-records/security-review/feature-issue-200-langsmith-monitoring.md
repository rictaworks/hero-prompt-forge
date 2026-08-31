# セキュリティレビュー : feature-issue-200-langsmith-monitoring

- 実施日時（JST）：2026-08-31 18:30
- 差分の指紋：eb08099e86aa3540
- 対象：issue #200

## 判定

合格

## 追加した機能の弱点確認

| 観点 | 内容 |
|---|---|
| 新規の外部送信先 | LangSmith（`https://api.smith.langchain.com/runs`）。送るのは指示文・磨く対象の英文・返ってきた英文・モデル名・所要時間のみ |
| 利用者を識別できる情報の混入 | `GeminiClient#refine`が受け取る`instruction`・`lines`をそのまま渡す設計で、Geminiへ送る内容と完全に同じ。認証情報・X ユーザーID・セッションは呼び出し経路に一切含まれない |
| 鍵の扱い | `LANGSMITH_API_KEY`を環境変数から読み、見出し（`x-api-key`）で送る。URLへ載せない。ソース・設定ファイルに書かない |
| 未設定時の挙動 | `available?`が`false`を返し、`log_success`/`log_failure`とも即`return`。開発・テストでは既定で未設定のため送信自体が起きない |
| 本業への影響 | `FAILURES`（`SocketError`等 + `StandardError`）を`send_run`内で受け止め、`Rails.logger.warn`へ残すのみ。`Metrics::SideChannel`と同じ設計で、LangSmithへの送信失敗が生成処理へ波及しない。実機テストで確認済み（`LangSmithへの送信が失敗しても、結果を返します`） |
| プライバシーポリシー・利用規約の開示 | `legal.ts`の利用規約 第7条・プライバシーポリシー 第4条・第6条へLangSmithの利用目的・送信内容・保存期間の考え方を追加。`requirements.md`にLangSmithは元々技術スタックとして記載済み（38行目）で、スコープ外の追加ではない |

## 実施した検査

| 検査 | 方法 | 結果 |
|---|---|---|
| 資格情報の混入 | ステージ差分への正規表現検査（password / secret / api key / token / private key） | 検出なし（`MissingApiKeyError`はクラス名のマッチのみ） |
| 送信内容の絞り込み | テスト（`指示文・素材・返ってきた文だけを送ります`） | `inputs`/`outputs`に指示文・素材・返答のみが含まれ、識別子を含まないことを確認 |
| 鍵の送り先 | テスト（`鍵を見出しで送ります`） | `x-api-key`ヘッダで送り、URLへ含まれないことを確認 |
| 未設定時の非送信 | テスト（`鍵が無ければ記録しません`） | 確認済み |
| 送信失敗時の非波及 | テスト（`LangSmithへの送信が失敗しても、結果を返します`） | 確認済み |
| 回帰 | `bundle exec rspec`（全体） | 1998例・失敗0件 |
| フロントエンド回帰 | `npm test`（全体）・`npx tsc --noEmit`・`npm run lint`・`npm run build` | いずれも成功 |
| ハードコード検出 | `npm run check:hardcode` | 検出0件 |

## 指摘

指摘はありません。
