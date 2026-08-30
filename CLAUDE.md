# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Claude Safety Rules

## 削除系コマンドの禁止（重要）

以下のルールはこのワークスペース内のすべての会話で絶対に守られる：

- Claude はファイルまたはディレクトリを削除するコマンドを一切生成してはならない。
  例：rm, rm -rf, rm *, rmdir, unlink, cache --delete,
      lftp mirror --delete, rsync --delete, git clean -df, find -delete 等。

- 削除が必要な場合でも、Claude は削除コマンドを提案せず、
  「手動で削除してください」といった説明に留めること。

- 削除の推奨・削除操作の自動判断も禁止。

- ssh / lftp / デプロイ系スクリプトを生成する場合でも、
  削除コマンドの生成は禁止。

これらはすべての会話・コード生成に適用される。

不要になったファイルは削除せず `DELETE/`（ゴミ箱）へ移動する。

## シークレット管理（重要）

- `config/master.key` など機密ファイルを `git add` するコードを生成してはならない
- デプロイスクリプト・セットアップ手順でも同様
- シークレットは必ず環境変数（RAILS_MASTER_KEY 等）で渡すこと
- `.gitignore` への追加を確認する手順を必ずコードに含めること
- 初回コミット前に `git status` でステージング確認を促すこと

---

# hero-prompt-forge

ウェブサイトのヒーローイメージ用プロンプトを、アートディレクター水準の具体性で生成するウェブアプリケーションです。

**仕様の正は `requirements.md`（製品版フルエディション）です。** 本ファイルは開発の進め方を定めます。

## 最重要

本事業は **B2B** です。**コンテンツはすべて「ですます調」で書きます。「だ・である調」を禁止します。**
README・UI 文言・PR 本文・Issue・ドキュメントのいずれも対象です。

## 開発の正・作業場所

- 開発の正は **WSL の `~/github/rictaworks/hero-prompt-forge`** です。
- 時刻は **JST**、ファイルのエンコードは **UTF-8** です。

## 開発コマンド

開発は WSL2 の dev コンテナ（`docker compose`）で行います。`.env` が無いと `db`／`dev` とも起動に失敗します（`POSTGRES_USER` 等、既定値を持ちません）。

```bash
docker compose up -d db dev                          # 起動（db がヘルシーになってから dev が立つ）
docker compose exec -T dev bash                       # 入室
```

### バックエンド（Rails、`src/backend`）

```bash
docker compose exec -T -w /workspace/src/backend -e RAILS_ENV=test dev bundle exec rspec
docker compose exec -T -w /workspace/src/backend -e RAILS_ENV=test dev bundle exec rspec spec/path/to/file_spec.rb   # 単体
docker compose exec -T -w /workspace/src/backend -e RAILS_ENV=test dev bundle exec rspec spec/path/to/file_spec.rb:42  # 単一の例
docker compose exec -T -w /workspace/src/backend dev bundle exec rubocop
docker compose exec -T -w /workspace/src/backend dev bundle exec rubocop -a   # 自動修正
```

`RAILS_ENV=test` の明示が必須です（`.env` の `RAILS_ENV=development` が `env_file` 経由でコンテナへ入りますが、`rails_helper.rb` の `ENV['RAILS_ENV'] ||= 'test'` は上書きしないため、明示しないと development 環境でテストが走ります）。

### フロントエンド（Next.js、`src/frontend`）

```bash
docker compose exec -T -w /workspace/src/frontend dev npx tsc --noEmit
docker compose exec -T -w /workspace/src/frontend dev npm run lint     # ESLint（flat config、引数無しで全体）
docker compose exec -T -w /workspace/src/frontend dev npm test         # Jest
docker compose exec -T -w /workspace/src/frontend dev npm test -- path/to/file.test.tsx   # 単体
docker compose exec -T -w /workspace/src/frontend dev npm run build
```

### リポジトリ直下の検査

```bash
npm run test:e2e            # Playwright（test/pr<番号>/ 配下）
npm run test:e2e -- test/pr191/foo.spec.ts   # 単体
npm run test:hardcode       # 文言直書き検出の仕組み自体のテスト
npm run check:hardcode      # 実際の直書き文言の検出
npm run test:hooks          # 開発フック（コミット前セキュリティレビュー等）の検査
npm run test:harness        # テストハーネスの検査
npm run test:docs           # ドキュメントの検査
npm run test:all            # 上記をまとめて実行
```

CI（`.github/workflows/ci.yml`）は上記に加え、`production-boot` ジョブで `RAILS_ENV=production`・`DATABASE_URL` のみを与えた `bin/rails db:prepare` を実行し、本番相当の起動条件を検査します（`config/database.yml` は環境ごとの節を分けていても、Rails がファイル全体の ERB を評価するため、他環境向けの環境変数が無いだけで起動に失敗しうることに注意）。

## ディレクトリ構成

| パス | 用途 |
|---|---|
| `src/` | **実装**。ここ以外にアプリケーションコードを置きません |
| `test/pr<番号>/` | PR ごとのテスト。`src` の外に置きます |
| `app-ui/` | 画面モック（Claude Design 由来）と、その静的実装 |
| `SPEC/` | 仕様書・リバースエンジニアリング図（ER 図・DFD・シーケンス図・クラス図・状態遷移図・ユースケース図） |
| `TASKS/` | タスク |
| `DEBUG/` | バグ報告 |
| `CLIENT/` | クライアント要望 |
| `WORK/` | 作業報告 |
| `ENV/DEVELOPMENT.md` | 開発環境 |
| `ENV/PRODUCTION.md` | 本番環境 |
| `DOCS/` | 共有リファレンス（CRAP.md・DP.md・TM.md） |
| `DELETE/` | ゴミ箱。削除の代わりにここへ移動します |
| `.claude/agents/` | サブエージェント定義 |
| `review-records/` | セキュリティレビュー・reviewer・pr-checker の記録（PR ごと） |

開発用スクリプトなど、アプリケーションでないものは `src` の外に置きます。
図解は Mermaid で書きます。

### 秘匿情報

**`.claude/` 直下の md は秘匿情報です。** 内容をチャット・PR・Issue・README へ転記しません。`.gitignore` で `.claude/*.md` を除外しています。`.claude/agents/` ・フック・skills は対象外で、追跡します。

`CLIENT/` `DEBUG/` `ENV/` `TASKS/` `WORK/` も内部情報のため追跡対象外です。

## 技術スタック

**Next.js + Rails + PostgreSQL** を基本とします。必要な場合のみ、AI・解析・画像加工に FastAPI、高速並列処理・リアルタイム通信に Gin を足します。

| 層 | 技術 |
|---|---|
| フロントエンド | Next.js（TypeScript）／ Vercel |
| バックエンド API・管理画面 | Ruby on Rails ／ Railway |
| DB | PostgreSQL |
| プロンプト精緻化 | LangChain（LangSmith / LangGraph を含む） |
| Bot 対策 | reCAPTCHA |

規模に応じて、マイクロサービスアーキテクチャ・MVC アーキテクチャ・API Gateway・メッセージングを意識します。

**メンテナンスコストとセキュリティの観点から、安全なライブラリ・フレームワーク・OSS・SaaS を使い、車輪の再発明を避け、オリジナルコードを少なく保ちます。**

## アーキテクチャ概要

### 通信経路とドメイン隠蔽

ブラウザが直接触れるのは Next.js（`src/frontend`）だけです。**バックエンド（Rails）のドメインは公開しません。** `next.config.ts` の `headers()` に加え、`rewrites()`（`src/config/backend.ts` の `backendRewrites()`）が `/api/*`・`/auth/*` をサーバー側だけが知る `BACKEND_INTERNAL_URL`（`NEXT_PUBLIC_` を使わない = ブラウザへ配らない）へ中継します。ブラウザからは常に画面と同じオリジンの `/api/...`・`/auth/...` だけが見えます。

### 認証（X ログイン）

X の OAuth 2.0 + PKCE でログインし、`services/auth/x_oauth_client.rb` がトークン交換を担います。**フォロワー判定（`@rictaworks` のフォロワーのみ利用可）は自前で持たず、`services/follower_gate_client.rb` が姉妹リポジトリ `x-follower-gate`（別ドメイン、隠蔽）へ問い合わせます。** `services/auth/plan_updater.rb` が判定結果を利用者のプラン値へ反映し、`services/auth/recheck_service.rb` が再判定を行います。開発・テストのみ `DEVELOPMENT_AUTO_LOGIN_X_USER_ID` で自動ログインでき、`APP_ENV=production` では無視されます（CI の `production-boot` ジョブが毎回確認）。

### 生成パイプライン

利用者がフォームで送信すると `PromptRequest` が作られ、`QUEUED → GENERATING → (COMPLETED | DEGRADED_COMPLETED | FAILED)` と状態が進みます（`app/models/prompt_request.rb`）。実際の組み立ては `GeneratePromptJob` が非同期に行い、中身は `Generation::PromptGenerationService`（`app/services/generation/prompt_generation_service.rb`）が持つ**11段の固定順パイプライン**です：入力正規化 → 禁止入力検出 → 日本語固有名詞の保持 → スタイル系統の仕様化 → コピースペースの規定 → アンチAIルック規則の適用 → 3案への展開 → 矛盾解決・統合 → LLM精緻化（LangChain 経由 Gemini、失敗時は縮退）→ モデル別整形（`services/adapters/*`）→ アートディレクションノート。**各段は「下書きを受け取って下書きを返す」部品で、順序をこのサービスだけが持ちます**（順序を変えると規則が効かなくなる実例が `prompt_generation_service.rb` 冒頭のコメントに記録されています）。

規則の元データは `RuleDictionary`（管理画面 `/admin/rule-dictionaries` から編集・公開）で、1回の生成の間は版を1つに固定します。

**取りこぼし対策**：ワーカーが異常終了すると `GENERATING` のまま残る行が出ます。`ReclaimPromptRequestsJob` が定時に「動きが無いまま一定時間を超えた行」「決着済みだがクォータの予約が残ったままの行」を拾い直し、`GeneratePromptJob` へ再投入します（1回あたり `BATCH_SIZE` 件まで）。**同じ理由で毎回落ちる行は打ち切り（`cut_off!`）として扱い、際限のない再投入を防ぎます。**

### クォータ

1アカウント1日1回の制限を `Quota::QuotaDay`（`app/services/quota/quota_day.rb`、リセットは **JST 03:00**、日付境界ではない）と `QuotaConsumption`（`reserved → confirmed / refunded`、`refunded → reserved` で当日中の作り直しを許可）で管理します。**「同じ日に2件」はアプリのバリデーションだけでなく、DBの一意制約（`user_id` × `quota_day`）で担保**しています。予約はリクエスト作成より前に行うため、予約時点では `prompt_request_id` が空になりえます。

### 管理画面

`/admin` 配下は Basic 認証（`services/admin/credentials.rb`）で保護され、利用者向け画面とは入口を分けています（`requirements.md` 5.2）。規則辞書・利用者とプラン値・利用状況（`services/metrics/*`）を扱います。

## 開発フロー

```
issue → setting & coding → security review → add, commit, push
      → reviewer & pr-checker → merge → …
      → code-review → audit & security-gate → release → user test
```

- **TDD を厳守します**：plan → red test → coding → green test（RSpec / Jest 等）。
- **コミット前に必ずセキュリティレビューを行います**（フックで強制します）。
- **マージ前に必ず reviewer と pr-checker を実行します**（フックで強制します）。
- フロントの確認は `curl` / `wget --mirror` / Playwright で行います。

## ブランチ・PR

- **`main` ブランチでの作業を禁止します。**
- **`src/**` の変更は必ず PR を作成します。直接 push を禁止します。**
- `src/**` 以外（ドキュメント・`SPEC/`・`TASKS/` 等）は `main` への push を許可します。
- **PR には非エンジニア向けのユーザーテストを丁寧に書きます。** 非エンジニアとは、ブラウザしか使わない人のことです。

## コーディング規約

- **フォールバックを禁止します。** 例外処理をしっかり書きます。想定外は握りつぶさず失敗させます。
- **デバッグトレースができるように書きます。**
- **制御構文・条件構文以外はクラスまたは関数に書きます。**
- **グローバル変数を禁止します**（セキュリティの観点）。
- **文字列リテラルをファイルまたはデータベースへ分離します。ハードコードを検出するテストを書きます。**（フロントは `src/strings/`、検査は `npm run check:hardcode`）
- **ネイティブの `alert()` / `confirm()` / `prompt()` をプロジェクト全体で禁止します。**
- 環境変数は `.env` を参照します。
- **環境の判定を必ず実装して分岐できるようにします。** テスト可能にするため、開発環境は認証済みに分岐します。ただし**開発者向けの近道を本番の UI に露出しません**。
- **日本語版のみ開発します。** 多言語化を実装しません。
- アイコンは **Font Awesome** を既定とします。**絵文字を禁止します。**
- 連絡先に個人名を使いません。メールは `info@rictaworks.jp` です。
- **README.md と `SPEC/` に未実装のものを書きません。**

## デザイン

事前のデザイン指定は `app-ui/` にモックとして置いてあります。**モックに従います。**
アプリケーションは、このモックを `src` に再現して裏をつないでいきます。

**モックはモックです。** ダミーのブランド名・アカウント名・数値が本番設定と違っても、モックを書き換えません。正しい値は実装側で入れます。

画像は AI 生成します。プロのライティングは `writer` エージェントに行わせます。

## 認証

- **X ログイン**（`@rictaworks` のフォロワーのみログイン可）です。
- **X のフォロワー判定を新規実装しません。** `https://github.com/rictaworks/x-follower-gate` を使います。
- **一般消費者が実際に使える手段でログインできること**を必須とします。開発者向けの近道を本番の UI に出しません。

## デプロイ

- フロントは無料 **Vercel**、バックエンドと管理画面は無料 **Railway** を原則とします。
- **デプロイはヘッドレスで実行します。**
- **バックエンドのドメインを隠蔽します。**
- ドメインは原則 `rictaworks.jp` のサブドメインです。
- **CI/CD は必須です。CD は Claude Desktop で設定します。**
- **GitHub Releases をトリガーとしてデプロイします。** Releases をトリガーに、audit & security gate をデスクトップで実施します。
- **Railway・Vercel いずれのサービスも、GitHub の push を検知した自動デプロイ（サービス側の Source 連携）を設定しません。** デプロイは `.github/workflows/release-deploy.yml`（Release 発行がトリガー）の `railway up` / `vercel deploy --prod`、またはデスクトップからの手動実行のみで行います。**サービス側の「Connect Repo」でブランチを連携すると、CI・security-gate・タグ付けを経ないコードが push のたびに無審査で本番へ到達します**（2026-08-31、`backend` サービスの `main` 連携が実際にこの状態になっていたため切断した実績あり）。新規サービスを作る際・既存サービスの Source 設定を確認する際は、必ず GitHub 連携が外れていることを確かめます。

## リリース・バージョン

- バージョン番号は **メジャー2桁.マイナー2桁.デバッグ2桁**、初期値は **`01.01.00`** です。
- **タグは最初から `git tag -a`（注釈付き）で作ります。**
- 版管理対象として、**バージョン刻みの意味規則・タグ形式・必須添付物**を定めます。これが無いと監査が「規程不在」で判定不能を返し、合格に届きません。
- **検証・承認の記録を版管理対象のログに残します。**

## AI API

- **Gemini** を使います。利用可能なモデルを調べ、**最安値のモデル**を選びます。
- 画像生成が必要な場合は nano banana を使います。
- 有償 API は単価を調べ、見積もりを提示してから使います。

## サブエージェント

| agent | 役割 |
|---|---|
| `director` | 方針決定・優先順位付け・受け入れ判断 |
| `project-manager` | Issue 起票・タスク分解・進捗管理 |
| `designer` | 画面設計・`app-ui` モックの解釈・CRAP 適合 |
| `writer` | コンテンツのプロライティング（ですます調） |
| `debugger` | 不具合の再現・切り分け・原因特定 |
| `tester` | テスト作成（全 PR 対象・`test/pr<番号>/`） |
| `reviewer` | コードレビュー（受け入れ要件・各基準の適合） |
| `pr-checker` | PR タイトル・本文の日本語化とユーザーテスト記載 |
| `data-scientist` | 測定軸の集計・KPI 分析 |
| `deployer` | デプロイ実行（ヘッドレス） |
| `service-manager` | 運用・監視・障害対応 |

## 参照文書

| ファイル | 用途 |
|---|---|
| `requirements.md` | **仕様の正** |
| `DOCS/CRAP.md` | デザイン4原則 |
| `DOCS/DP.md` | 設計原則 |
| `DOCS/TM.md` | テストメソッド |
| `.claude/QC10.md` | 品質管理10項目（秘匿） |
| `.claude/OWASP10.md` | セキュリティ（秘匿） |
| `.claude/CC.md` | コンプライアンス（秘匿） |
