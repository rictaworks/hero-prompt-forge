# test

ブラウザ操作による確認（Playwright）の置き場所です。**`src` の外に置きます。**

## 置き方

```
test/pr<PR番号>/*.spec.ts
```

PR ごとにディレクトリを分けます。各ファイルは、その PR の本文に書かれた
**非エンジニア向けユーザーテスト手順と1対1で対応**させます。手順に無い操作を足しません。

### 置かない場合

**画面の操作を伴わない PR には置きません。**

裏側だけを変える PR（API・ジョブ・モデル・規則の実装）では、非エンジニア向けの
ユーザーテスト手順が「GitHub の PR 画面で自動検査が緑であること」「変更された
ファイルの並びを見ること」になります。**ブラウザで操作する対象がありませんので、
Playwright で自動化できる手順がありません。**

**置かない代わりに、PR 本文へ「この PR は画面を持ちません」と明記します。**
できない確認を、できるように書きません。

画面（`src/frontend/`）を変える PR では、必ず置きます。

## 開発の道具そのものの検査

開発フック（`scripts/hooks/`）とハードコードの検査は、道具そのものが正しく
働くかを確かめるテストを持ちます。

```
test/hooks/*.test.mjs        マージ前フックの検査
test/hardcode/*.test.mjs     ハードコード検出の検査
test/harness/*.test.mjs      テストの置き場が実行から漏れていないかの検査
test/docs/*.test.mjs         README と SPEC が実装と合っているかの検査
```

**これらは `test/pr<番号>/` に置きません。** PR ごとの確認ではなく、**道具そのものが正しく働くかを見る検査**だからです。持ち場ごとに 1 つの置き場を持ちます。

いずれも `node --test` で動かします。**一時ディレクトリへ作った最小の
リポジトリを対象にします。** このリポジトリの `review-records/` を対象にすると、
記録が増減するたびに結果が変わります（`.claude/TEST-HARNESS-SAFETY.md` の TH4）。

```bash
npm run test:hooks
npm run test:hardcode
npm run test:harness
```

### 束ねる実行

```bash
npm run test:all
```

**Playwright（`npm run test:e2e`）は束ねません。** 開発サーバーが動いていないと
実行できず、束ねると「サーバーが無い」だけで全体が落ちます。**自動検査では
`e2e` という別のジョブで走ります**（下記）。

**新しい置き場を `test/` へ足したら、`package.json` へ実行を足してください。**
足さないと `npm run test:harness` が失敗します（issue #142）。
`pr` で始まる置き場は Playwright が拾いますので、実行を足す必要はありません。

## レビューのための一時的な作業ツリー

reviewer・pr-checker が PR の内容を実際に動かして確かめる場合は、`DELETE/`
（ゴミ箱、リポジトリ直下の README.md を参照）の下に `git worktree` を作ります。
**dev コンテナから見える位置に作る必要があります。**

```bash
git worktree add DELETE/review-worktrees/pr<PR番号>-<日付>-<担当> origin/<ブランチ名>
docker compose exec dev bash -c 'cd /workspace/DELETE/review-worktrees/pr<PR番号>-<日付>-<担当>/src/backend && bundle exec rspec'
```

**置き場は `DELETE/` の下の 1 か所に統一します。** 以前はここに `/.review/`
という別の置き場も書かれており、`.gitignore` にも専用の除外行がありました。
**ただし実際の運用では、ほぼすべてのレビュー記録が最初から `DELETE/` の下に
作業ツリーを作っており、`/.review/` を経由していません。** PR #179 の
pr-checker が「置き場の指定が 2 通りある」と指摘していました（issue #184）。
`DELETE/` は「削除の代わりに移動する場所」としてすでにプロジェクト全体で
使われていますので、レビュー用の作業ツリーもそこへ寄せます。**使われなく
なった `/.review/` の除外行も `.gitignore` から取り除きました。**
**別の置き場を新たに増やしません。**

`DELETE/` は `.gitignore` で版管理から外しています（もとから追跡されていた
ファイルを `git mv` した場合を除きます）。**確認が終わっても `git worktree`
を削除コマンドで消さず、`DELETE/` の下に残したままにします。** 実装側の
作業ツリーでブランチを切り替えないでください。別の作業と衝突します。

## 実行

```bash
docker compose exec dev bash -c 'cd /workspace && npx playwright test'
```

接続先は `E2E_BASE_URL` から読みます。**開発サーバーのみを対象とします。**
本番環境の URL を指定した場合は、設定の読み込み時点で失敗します。

## 自動検査（CI）での実行

**`test/pr*/**/*.spec.ts` は、`main` へ取り込む前に必ず走ります。**
`.github/workflows/ci.yml` の `e2e` ジョブが実行します。

| 手順 | 内容 |
|---|---|
| 1 | PostgreSQL を立ち上げ、`bin/rails db:prepare` で表を作ります |
| 2 | 自動ログインの利用者を 1 名作ります（`DEVELOPMENT_AUTO_LOGIN_X_USER_ID`） |
| 3 | 画面を組み立てます（`npm run build`） |
| 4 | バックエンド（3001）と画面（3000）を起動し、**応答を確かめてから**次へ進みます |
| 5 | `npx playwright test` を走らせます |

**走らせる条件を絞りません。** すべてのプルリクエストと、`main` への取り込みで走ります。
変更したファイルで絞ると、**「画面を触っていないつもりの変更」が画面を壊したときに
気づけません。** 実際に PR #170 では、「バックエンドのドメインを隠蔽する」という
約束を守る唯一のテストが Playwright だけにありました。

**接続先は開発サーバーだけです。** ジョブは `E2E_BASE_URL` に `http://localhost:3000` を
与えます。本番を指した場合は、設定の読み込みの時点で失敗します。

**この決まりは `npm run test:harness` が見張ります。** ジョブを外すと、検査が赤くなります。
