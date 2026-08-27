# hero-prompt-forge

ウェブサイトのヒーローイメージ（ファーストビューの主画像）を画像生成 AI で制作する際に、プロ仕様のプロンプトを生成するウェブアプリケーションです。

生成 AI の出力にありがちな「AI っぽさ」（クリシェ的な配色・意味のないオブジェクト・破綻した人物表現）を設計段階で排除し、アートディレクターが指示する水準の具体性を持つプロンプトを出力します。

仕様の正は [requirements.md](requirements.md) です。開発の進め方は [CLAUDE.md](CLAUDE.md) にあります。

## 現在の状態

**利用者の画面と、開発者用の管理画面が動きます。** X でログインし、条件を入れて生成をお申し込みし、3 案を受け取り、評価メモを残すところまで通ります。

**実装から起こした図は [SPEC/](SPEC/) にあります**（ER 図・クラス図・状態遷移図・シーケンス図・DFD・ユースケース図）。

## 自動ログイン

**開発と検査でだけ効く自動ログインがあります。** 本番では効きません。

| 環境変数 | 中身 |
|---|---|
| `DEVELOPMENT_AUTO_LOGIN_X_USER_ID` | 自動でログインさせる X の数値のユーザー ID です |

**次の 2 つが揃ったときだけ有効です。**

1. `APP_ENV` が `development` または `test` であること
2. その X のユーザー ID を持つ利用者が、データベースに居ること

**本番（`APP_ENV=production`）では、値が設定されていても無視します。** 自動検査の「本番と同じ設定での読み込み確認」が、毎回そのことを確かめています。

**この近道を、本番の画面に出しません。** 一般の方は X ログインだけで入ります。

## ページ一覧

**すべて Next.js の画面です。** 下の URL は、手元の開発環境（`http://localhost:3300`）での住所です。

| ページ名 | URL | ログイン |
|---|---|---|
| 01 ランディング | [/](http://localhost:3300/) | 要りません |
| 02 履歴・一覧 | [/projects](http://localhost:3300/projects) | 要ります |
| 03 入力フォーム | [/requests/new](http://localhost:3300/requests/new) | 要ります |
| 04 生成中 | [/requests/:id](http://localhost:3300/requests/1) | 要ります |
| 05 結果 3 案 | [/requests/:id/result](http://localhost:3300/requests/1/result) | 要ります |
| 06 評価メモ | [/requests/:id/notes](http://localhost:3300/requests/1/notes) | 要ります |
| 07 プリセット | [/presets](http://localhost:3300/presets) | 要ります |
| 利用規約 | [/terms](http://localhost:3300/terms) | 要りません |
| プライバシーポリシー | [/privacy](http://localhost:3300/privacy) | 要りません |
| 特定商取引法に基づく表示 | [/commerce](http://localhost:3300/commerce) | 要りません |

**08 縮退・エラーは、独立したページではありません。** 04 ・ 05 の画面の中で、縮退・上限到達・差し戻しとして出ます。

**09 管理は、利用者の画面から辿れません**（`requirements.md` 5.2）。開発者用の管理画面は入口を分けています。

### 開発者用の管理画面

**BASIC 認証が掛かります。** 一般の方は使いません。**本番の住所は公開しません。**

| ページ名 | パス |
|---|---|
| ダッシュボード | `/admin` |
| 規則辞書 | `/admin/rule-dictionaries` |
| 利用者とプラン値 | `/admin/users` |
| 利用状況 | `/admin/metrics` |

### 画面モック

`app-ui/` にある画面モックは、ローカルで表示できます。製品のページではありません。

| 画面 | 原本 | 静的実装 |
|---|---|---|
| 01 ランディング | [Landing.dc.html](app-ui/Landing.dc.html) | [index.html](app-ui/index.html) |
| 08 縮退・エラー | [Degraded.dc.html](app-ui/Degraded.dc.html) | [degraded.html](app-ui/degraded.html) |

表示方法は [app-ui/README.md](app-ui/README.md) にあります。

## API 一覧

**基底パスは `/api/v1` です。** 契約は [SPEC/api/README.md](SPEC/api/README.md) にあります。

**バックエンドの住所を公開しません。** 画面からの呼び出しは、画面の中の中継を通ります。

| タイトル | エンドポイント | 仕様 |
|---|---|---|
| ログイン中の利用者 | `GET /api/v1/session` | [SPEC/api](SPEC/api/README.md) |
| プロジェクトの一覧 | `GET /api/v1/projects` | [SPEC/api](SPEC/api/README.md) |
| プロジェクトを作ります | `POST /api/v1/projects` | [SPEC/api](SPEC/api/README.md) |
| プロジェクトを更新します | `PATCH /api/v1/projects/:id` | [SPEC/api](SPEC/api/README.md) |
| プリセットの一覧 | `GET /api/v1/presets` | [SPEC/api](SPEC/api/README.md) |
| プリセットを呼び出します | `GET /api/v1/presets/:id` | [SPEC/api](SPEC/api/README.md) |
| プリセットを保存します | `POST /api/v1/presets` | [SPEC/api](SPEC/api/README.md) |
| プリセットを更新します | `PATCH /api/v1/presets/:id` | [SPEC/api](SPEC/api/README.md) |
| 生成履歴の一覧 | `GET /api/v1/prompt_requests` | [SPEC/api](SPEC/api/README.md) |
| 生成をお申し込みします | `POST /api/v1/prompt_requests` | [SPEC/api](SPEC/api/README.md) |
| 状態と 3 案を取り出します | `GET /api/v1/prompt_requests/:id` | [SPEC/api](SPEC/api/README.md) |
| 評価メモを取り出します | `GET /api/v1/prompt_outputs/:id/evaluation_note` | [SPEC/api](SPEC/api/README.md) |
| 評価メモを記録します | `POST /api/v1/prompt_outputs/:id/evaluation_note` | [SPEC/api](SPEC/api/README.md) |
| 評価メモを更新します | `PATCH /api/v1/prompt_outputs/:id/evaluation_note` | [SPEC/api](SPEC/api/README.md) |

### ログインと死活監視

| タイトル | エンドポイント | 認証 |
|---|---|---|
| ログインを始めます | `GET /auth/start` | 要りません |
| 認可から戻ります | `GET /auth/callback` | 要りません |
| ログアウトします | `DELETE /auth/session` | 要ります |
| 死活監視 | `GET /health` | 要りません |

**`/health` は、データベースへ到達できることまで含めて答えます。**

## ディレクトリ構成

| パス | 用途 |
|---|---|
| `src/` | 実装 |
| `test/pr<番号>/` | PR ごとのテスト |
| `app-ui/` | 画面モックと静的実装 |
| `SPEC/` | 仕様書・リバースエンジニアリング図 |
| `DOCS/` | 共有リファレンス |
| `review-records/` | セキュリティレビュー・reviewer・pr-checker の記録 |
| `scripts/` | 開発用スクリプト |
| `DELETE/` | ゴミ箱 |

## 開発

- 開発の正は WSL の `~/github/rictaworks/hero-prompt-forge` です。
- 時刻は JST、ファイルのエンコードは UTF-8 です。
- `main` ブランチでの作業を禁止します。`src/**` の変更は必ず PR を作成します。
- コミット前にセキュリティレビュー、マージ前に reviewer と pr-checker の実行が必要です。フックで強制しています。

## お問い合わせ

info@rictaworks.jp
