# test

ブラウザ操作による確認（Playwright）の置き場所です。**`src` の外に置きます。**

## 置き方

```
test/pr<PR番号>/*.spec.ts
```

PR ごとにディレクトリを分けます。各ファイルは、その PR の本文に書かれた
**非エンジニア向けユーザーテスト手順と1対1で対応**させます。手順に無い操作を足しません。

## 実行

```bash
docker compose exec dev bash -c 'cd /workspace && npx playwright test'
```

接続先は `E2E_BASE_URL` から読みます。**開発サーバーのみを対象とします。**
本番環境の URL を指定した場合は、設定の読み込み時点で失敗します。
