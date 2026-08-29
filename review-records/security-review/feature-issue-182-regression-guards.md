# セキュリティレビュー : feature/issue-182-regression-guards

- 実施日時（JST）：2026-08-29
- 差分の指紋：220fb673b5b96d89
- 対象：issue #182

## 判定

合格

## 実施した検査

| 検査 | 方法 | 結果 |
|---|---|---|
| 資格情報の混入 | gitleaks 8.30.1 `protect --staged` | 検出なし |
| 秘匿値のハードコード | 差分の目視 | テスト用の既存フィクスチャ値（`admin-for-spec` 等）のみ。新規の秘匿値は無し |
| 危険な描画（XSS） | 実装 | `error.tsx` は `<button>` を `Button` コンポーネントへ置き換えたのみで、危険な描画（`dangerouslySetInnerHTML` 等）は無し |
| 認可・認証ロジックの変更 | 実装の目視 | `AuthenticatesAdmin` / `Admin::Credentials` の判定ロジック自体は不変。定数の重複解消（別名の削除）と、直接の検めるテストの追加のみ |
| SQL インジェクション | 実装の目視 | 新規の生SQLは無し。`YAML.safe_load_file` は既存の使用パターンを踏襲 |
| ログへの秘匿値出力 | 実装の目視 | 新規のログ出力は無し |
| 入力検証 | 実装の目視 | 利用者入力を扱う新規経路は無し（すべてテスト・整備） |
| 文言の直書き | `npm run check:hardcode` | 検出なし |

## 指摘

指摘はありません。

## 補足

- 本変更は issue #182（後戻り検知テストの追加・重複の整理）で、production のロジックを変更する箇所は次の3点のみ：
  - `style_spec.rb`：`PERSON_SAFETY_ROLE` を `VariationBuilder` の定義へ一本化、`index_with(...).invert` を直接組み立てへ置換（挙動は不変・テストで確認済み）
  - `authenticates_admin.rb`：未使用だった別名定数（`USER_NAME_KEY` / `PASSWORD_KEY`）を削除（挙動は不変）
  - `recaptcha.ts` / `error.tsx`：テスト専用の抜け道（`resetLoader`）の削除、素の `<button>` を `Button` コンポーネントへ統一（挙動は不変）
- `resetLoader` の削除は、テスト専用のリセット関数が本番の公開面（named export）から消えるため、攻撃面をわずかに縮小する変更（プラスの効果）

---

## 2回目（記録のみの追加）

- 実施日時（JST）：2026-08-29
- 差分の指紋：e3b0c44298fc1c14（`review-records/` を除く差分は 0 バイトで、空文字列のハッシュと一致）
- 対象：reviewer 記録（`review-records/reviewer/pr187.md`）と pr-checker 記録（`review-records/pr-checker/pr187.md`）の追加のみ

### 判定

合格

### 実施した検査

| 検査 | 方法 | 結果 |
|---|---|---|
| 資格情報の混入 | gitleaks 8.30.1 `protect --staged` | 検出なし |
| コードの変更有無 | `git diff --cached -- . ':(exclude)review-records/'` | 0 バイト（記録ファイルの追加のみ） |

### 指摘

指摘はありません。
