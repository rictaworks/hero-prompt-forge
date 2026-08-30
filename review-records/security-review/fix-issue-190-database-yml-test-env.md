# セキュリティレビュー : fix-issue-190-database-yml-test-env

- 実施日時（JST）：2026-08-31 12:00
- 差分の指紋：f6546841bc4b08d3
- 対象：issue #190

## 判定

合格

## 直した弱点

| 弱点 | 影響 | 対応 |
|---|---|---|
| `database.yml` の `test:` 節が既定値なしで `TEST_DATABASE_URL` を要求していた | Rails は有効な `RAILS_ENV` だけでなくファイル全体の ERB を評価してから設定を組み立てるため、`RAILS_ENV=production` で `DATABASE_URL` しか渡していなくても `test:` 節の評価が走り、`TEST_DATABASE_URL` 未設定の本番コンテナは起動のたびに `KeyError` で落ちていた（可用性の問題） | `test:` 節に `ENV.fetch("TEST_DATABASE_URL", "postgresql://localhost/hero_prompt_forge_test")` と既定値を持たせた。development 節と同じ書き方に揃えた |
| `production-boot` ジョブが本番の起動条件を再現していなかった | `env:` に `DATABASE_URL` と一緒に `TEST_DATABASE_URL` を設定していたため、本番で実際に起きる「`TEST_DATABASE_URL` が無い」状態をこのジョブが一度も検査していなかった | `TEST_DATABASE_URL` を `env:` から外し、本番相当（`DATABASE_URL` のみ）で `bin/rails db:prepare` が通ることをジョブ自身が確かめる形にした |

## 実施した検査

| 検査 | 方法 | 結果 |
|---|---|---|
| 資格情報の混入 | 差分への正規表現検査（password / secret / api key / token / private key） | 検出なし（`SECRET_KEY_BASE: ci_boot_check_only_not_a_real_secret` は変更前から既存のプレースホルダーで、実在の秘密ではない） |
| 本番の接続先に既定値を持たせていないか | 目視・新規スペックで確認 | `production:` 節は既定値を持たず、`DATABASE_URL` 未設定時は従来どおり `KeyError` で落ちる（意図せず別のデータベースへ接続する経路を作っていない） |
| 既定値の妥当性 | 目視 | `test:` の既定値は `postgresql://localhost/hero_prompt_forge_test`（development 節の書き方と同型）で、本番の接続先を指していない |
| 実機再現：本番相当の環境変数（`TEST_DATABASE_URL` 未設定）での `db:prepare` | 実行（dev コンテナ、`RAILS_ENV=production` ・ `DATABASE_URL` のみ設定） | `KeyError` を起こさず成功。確認後、検証用に作成した DB は削除済み |
| 回帰 | `bundle exec rspec`（全体） | 1985 例・失敗 0 件 |
| 新規スペック | `bundle exec rspec spec/config/database_yaml_spec.rb` | 5 例・失敗 0 件 |

## 指摘

指摘はありません。
