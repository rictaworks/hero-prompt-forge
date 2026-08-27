# DFD（データフロー図）

**実装から起こした図です。** 実際に流れているものだけを載せます。

## 全体

```mermaid
graph TB
    利用者(("利用者"))
    ブラウザ["画面<br/>（Next.js）"]
    API["API・管理画面<br/>（Rails）"]
    DB[("PostgreSQL")]
    働き手["生成の働き手<br/>（Solid Queue）"]
    X["X（OAuth 2.0 + PKCE）"]
    Gate["x-follower-gate"]
    Google["reCAPTCHA（Google）"]
    Gemini["Gemini"]

    利用者 -->|入力条件| ブラウザ
    ブラウザ -->|"お申し込み・合図"| API
    API -->|"3 案・状態"| ブラウザ
    ブラウザ -->|"画面"| 利用者

    API -->|"認可の求め"| X
    X -->|"ユーザーID・表示名"| API
    API -->|"ユーザーID"| Gate
    Gate -->|"フォロワーかどうか"| API
    API -->|"合図"| Google
    Google -->|"得点"| API

    API <-->|"読み書き"| DB
    API -->|"投入"| 働き手
    働き手 <-->|"読み書き"| DB
    働き手 -->|"素材の英文"| Gemini
    Gemini -->|"磨いた英文"| 働き手
```

**画面はバックエンドの住所を持ちません。** 画面の中の中継（`BACKEND_INTERNAL_URL`）を通します。**ブラウザへ配りません。**

## 生成の流れ（詳細）

```mermaid
graph TB
    入力["入力条件"]
    正規化["入力の正規化<br/>Generation::InputNormalizer"]
    禁止["禁止入力の検出<br/>Generation::ForbiddenDetector"]
    差戻["差し戻し<br/>（枠を使いません）"]
    予約["枠の予約<br/>Quota::Reservation"]
    辞書[("規則辞書<br/>公開済みの最新版")]
    仕様化["スタイルの仕様化<br/>Generation::StyleSpec"]
    素材["素材の組み立て<br/>Generation::Draft"]
    精緻["LLM による精緻化<br/>Generation::LlmRefiner"]
    縮退["縮退の組み立て<br/>Generation::DegradedComposer"]
    変換["生成モデルごとの整形<br/>Adapters::*"]
    収め["3 案を収めます<br/>PromptRequests::Delivery"]
    確定["枠の確定"]

    入力 --> 正規化
    正規化 --> 禁止
    禁止 -->|見つかりました| 差戻
    禁止 -->|ありません| 予約
    予約 --> 仕様化
    辞書 --> 仕様化
    仕様化 --> 素材
    素材 --> 精緻
    精緻 -->|"通りました"| 変換
    精緻 -->|"呼べません・失敗しました"| 縮退
    縮退 --> 変換
    変換 --> 収め
    収め --> 確定
```

**禁止入力の検出は、枠の予約より先です。** 差し戻しは枠を使いません。

**LLM が使えない場合も止まりません。** 規則辞書だけで組み立てる縮退へ回ります（`requirements.md` 5.1）。**縮退で作った案には、その旨を明記します。**

## 外へ出す情報

| 宛先 | 送るもの | 送らないもの |
|---|---|---|
| X | 認可の求め（PKCE） | 生成の内容 |
| x-follower-gate | X のユーザー ID | 表示名・生成の内容 |
| reCAPTCHA（Google） | 秘密鍵・画面が受け取った合図 | **要求元のアドレス**・利用者の識別子・生成の内容 |
| Gemini | 指示文・磨く対象の英文 | 認証情報・利用者の識別子・セッション |

**LLM へ送るのは、利用者の入力条件から組み立てた素材だけです**（`requirements.md` 5.2）。

## 記録に残すもの

| 表 | 残すもの | 残さないもの |
|---|---|---|
| `metric_events` | 測定軸ごとの日別の件数 | **誰の分かを残しません** |
| `admin_actions` | 実施者・操作・対象・日時 | **合言葉を残しません** |
| `sessions` | 識別子のハッシュ・失効時刻 | **識別子そのものを残しません** |
