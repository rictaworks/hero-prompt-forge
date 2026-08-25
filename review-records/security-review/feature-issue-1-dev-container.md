# セキュリティレビュー : feature-issue-1-dev-container

- 実施日時（JST）：2026-08-25 10:04
- 差分の指紋：52699100d141ea06
- 対象：issue #1（dev コンテナ）
- 対象ファイル：`Dockerfile` / `docker-compose.yml` / `.devcontainer/devcontainer.json` / `src/.gitkeep`

## 判定

合格

## 実施した検査

| 検査 | 方法 | 結果 |
|---|---|---|
| 資格情報の混入 | gitleaks 8.30.1 `protect --staged` | 検出なし |
| 秘匿ファイルのステージ | `.env` / `master.key` / `*.pem` / `*.key` | 0 件 |
| 取得元の検証 | Dockerfile の外部取得 | NodeSource の GPG 鍵を取得して署名付きリポジトリとして登録しています。鍵の検証を経ない `apt` 追加や、スクリプトの直接実行（`curl \| bash`）を行っていません |
| 権限 | コンテナの実行ユーザー | `root` ではなく UID 1000 の `dev` で動きます |
| 公開範囲 | ポートの待ち受け | `127.0.0.1` のみに束縛しています。LAN へ露出しません |

## 開発用の資格情報について

`docker-compose.yml` に開発用データベースの利用者名とパスワードを直値で書いています。以下の理由により、本番の秘匿値の取り扱いには当たらないと判断しました。

- 開発コンテナ専用の値であり、本番では Railway Variables を使います。
- ポートを `127.0.0.1` に束縛しているため、開発機の外から到達できません。
- 値の名称自体に `development_only` を含め、本番への流用を防いでいます。

issue #5（`.env.example` と環境判定）で `.env` からの読み込みへ移します。

## 指摘

指摘はありません。
