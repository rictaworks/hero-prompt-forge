# hero-prompt-forge 仕様書（製品版フルエディション）

## 1. 概要

### 1.1 目的

ウェブサイトのヒーローイメージ（ファーストビューの主画像）を画像生成AIで制作する際の、プロ仕様のプロンプトを生成するウェブアプリケーションである。生成AIの出力にありがちな「AIっぽさ」（クリシェ的な配色・意味のないオブジェクト・破綻した人物表現）を設計段階で排除し、アートディレクターが指示するレベルの具体性を持つプロンプトを出力することで、ウェブサイトの第一印象を業務品質に引き上げる。

### 1.2 対象エディション

製品版フルエディション（納品用）。デザイン・測定・保守・監視の4軸をすべて実施する。

### 1.3 プラットフォームと選定理由

**ウェブ**を選択する。成果物であるプロンプトを直接読み・操作するのは人間（サイト制作者・デザイナー・マーケター）であり、ユーザーの入力に応じて出力が毎回変わる動的な処理と、生成履歴・プリセットの永続化を必要とするため、ウェブ・デスクトップ・スマホのいずれかが該当する。ブラウザ完結が最も導入障壁が低く、ローカル資源（GPU・ローカルLLM）を要求する理由がないため、ウェブとする。

### 1.4 リポジトリ名

`hero-prompt-forge`

## 2. 用語定義

| 用語 | 定義 |
|---|---|
| プロンプトパッケージ | メインプロンプト・ネガティブプロンプト・アートディレクションノート・バリエーション3案の一式 |
| アンチAIルック規則 | AI生成画像に典型的なクリシェ表現を排除するための規則群（禁止語彙とネガティブプロンプト対応表） |
| コピースペース | ヒーローイメージ上に見出し・CTAボタンを重ねるために確保する余白領域 |
| スタイル系統 | 実写（フォトリアル）／イラスト／3D／抽象の4分類 |
| モデルアダプタ | 生成モデルごとの記法（パラメータ・自然文・ネガティブ有無）に出力を整形する変換層 |
| プラン値 | ユーザーのアクセス権を表す単一項目。判定手段（フォロー判定等）から独立して保持する |

## 3. システム構成・技術スタック

| 層 | 技術 | 備考 |
|---|---|---|
| フロントエンド | Next.js（TypeScript） | 無料Vercelへデプロイ |
| バックエンドAPI | Ruby on Rails | 無料Railwayを優先、利用不可の場合のみRender |
| プロンプト精緻化 | LangChain（LangSmith / LangGraphを含む） | LLMによる表現の磨き込みに使用 |
| DB | PostgreSQL | |
| 管理画面 | Rails（同一バックエンド内） | BASIC認証 |
| Bot対策 | reCAPTCHA | 生成リクエストのフォームに適用 |
| 認証 | Xログイン（OAuth 2.0 + PKCE） | 指定アカウントのフォロワーであることを利用条件とする |

スケーラビリティ・高可用性のため、アプリケーションサーバーはステートレスに構成し、セッション状態はDBに置く。LLM呼び出しは非同期ジョブとしてキュー処理し、フロントはポーリングまたはサーバー送信イベントで結果を受け取る。

## 4. 機能要件

### 4.1 コア関数：ヒーローイメージプロンプト生成

本アプリの中核となる関数。以下の入力を受け取り、プロンプトパッケージを出力する。

**入力**

| 項目 | 必須 | 内容 |
|---|---|---|
| 業種 | ○ | 選択式（SaaS／飲食／医療／教育／不動産／製造／士業／EC／美容／その他） |
| スタイル系統 | ○ | 実写／イラスト／3D／抽象 |
| 生成モデル | ○ | Midjourney系／DALL-E系／Stable Diffusion系／nano banana系 |
| サービス概要 | − | 自由記述（日本語可） |
| ブランドトーン | − | 選択式（信頼感／先進性／温かみ／高級感／親しみ／ミニマル） |
| ブランドカラー | − | カラーコード（最大2色） |
| コピースペース位置 | − | 左／右／中央下（既定値：左） |
| アスペクト比 | − | 16:9／21:9／3:2（既定値：16:9） |

**処理ロジック（自然言語定義）**

1. **入力検証・正規化**：必須3項目の存在を検証する。任意項目の欠損は既定値で補完する（トーン未指定は業種ごとの標準トーンを適用する）。実在人物名・企業ロゴ・第三者著作物への言及を検出した場合は生成を行わず、理由を付してエラーを返す。
2. **アンチAIルック規則の適用**：規則辞書（マスタデータ）に基づき、AIクリシェに該当する表現の生成を抑止する語をメインプロンプトから排除し、対応するネガティブプロンプト（クリシェ配色・無意味な3Dオブジェクト・過剰な彩度・破綻した手指等）を注入する。
3. **プロ仕様具体化**：スタイル系統ごとの仕様化規則を適用する。実写系はレンズ焦点距離・照明設計（キーライト／フィルライト／リムライト）・被写界深度を明示する。人物を含む場合は顔・手指の破綻リスクを構図（後ろ姿・手元クロップ・遠景）で回避する。イラスト・3D系は線の質感・マテリアル・レンダリング様式を明示する。
4. **コピースペースの構図規定**：指定位置に基づき三分割構図と余白量を規定し、被写体・視線誘導が余白側と競合しない配置を指示する。
5. **矛盾解決**：入力間で規則が衝突する場合、優先順位「①コピースペース確保 ＞ ②ブランドカラー ＞ ③スタイル系統 ＞ ④トーン装飾」に従い、下位の指定を「示唆」レベルに弱めて統合する。ブランドカラーは画面全体の支配色ではなくアクセントとして自然に統合する。
6. **固有名詞の保持**：日本語固有名詞は翻訳せずローマ字表記で保持し、意味説明を併記する。
7. **モデル別整形**：モデルアダプタが、選択モデルの記法（パラメータ付与・自然文化・ネガティブプロンプトの分離）に出力を変換する。
8. **バリエーション生成**：構図の異なる3案（被写体主導／環境主導／抽象背景）を出力する。
9. **アートディレクションノートの付与**：各案に、生成後に人間が確認すべき観点（コピースペースの実際の可読性・ブランドカラーの再現度・クリシェ混入の有無）を記載したノートを添付する。

**出力**

プロンプトパッケージ（3案 × {メインプロンプト、ネガティブプロンプト（対応モデルのみ）、推奨パラメータ、アートディレクションノート}）。

### 4.2 設計原則（アンチAIルック）

以下を機能横断の設計原則として定める。

- クリシェ配色（紫〜ティールのグラデーション等）・意味を持たない浮遊オブジェクト・過剰な彩度とボケは、規則辞書により常時排除する。
- 実写系プロンプトには撮影指示（レンズ・照明・被写界深度）を必ず含める。撮影指示を欠くプロンプトは出力しない。
- 人物の顔を正面から大きく描写する構図は既定で回避し、ユーザーが明示的に指定した場合のみ許可する。
- すべての案にコピースペースの指定を含める。コピースペースを持たないヒーローイメージ用プロンプトは出力しない。
- 矛盾する入力を受けた場合も出力を停止せず、優先順位規則により統合した案を返す。ただし統合内容をアートディレクションノートに明記する。

### 4.3 付随機能

| 機能 | 内容 |
|---|---|
| プロジェクト管理 | サイト単位で入力条件を保存し、再生成・条件変更に用いる |
| プリセット | 入力条件の組み合わせを名前付きで保存・呼び出しする |
| 生成履歴 | プロンプトパッケージの履歴を保持し、過去案の再表示・複製を行う |
| プロンプト評価メモ | 生成画像を実際に作った結果の所感をユーザーが記録し、次回条件調整の参考とする |
| 管理画面 | 規則辞書（アンチAIルック規則・スタイル仕様化規則・業種既定値）の追加・編集、ユーザー・プラン値の管理、手動再判定、クォータの手動リセット |

### 4.4 利用回数制限（1アカウント1日1回）

プロンプト生成は1アカウントにつき1日1回とする。以下を要件とする。

- **クォータ日の境界**：リセット時刻はJST 03:00とし、03:00を境界とする「クォータ日」で消費を管理する。消費の帰属は**ジョブ投入（予約）時点**のクォータ日とし、生成完了がリセット時刻を跨いでも帰属は変わらない。
- **消費タイミング**：入力検証を通過しジョブ投入する時点で、クォータを**予約消費**する。（ユーザー × クォータ日）の一意制約により、二重送信・並列投入で同日2回以上通らないことをDBレベルで担保する。
- **消費の確定と返還**：
  - `completed`（通常完了）および `degraded_completed`（縮退完了）は、成果物を提供しているため消費を確定する。
  - `failed`（縮退も失敗）はクォータを返還し、当日中の再生成を可能とする。
  - `rejected`（禁止入力）はジョブ投入前に確定するため、クォータを消費しない。
  - `failed` からの再実行は同一リクエストの再実行として扱い、追加消費しない。
- **上限到達時の応答**：上限到達を明示し、次回リセット時刻（JST 03:00）を必ず提示する。曖昧なエラーを返さない。
- **手動リセット**：開発者（管理者）は管理画面から任意のユーザーの当日消費をリセットできる。リセットは実施者・日時とともに記録する。
- クォータはプラン値と独立した仕組みとし、将来のプラン拡張（回数の異なるプランの追加）時にクォータ上限をプラン値から導出できる構造とする。

## 5. 非機能要件

### 5.1 スケーラビリティ・可用性

- アプリケーションサーバーはステートレスとし、水平スケール可能な構成とする。
- LLM呼び出しは非同期ジョブとし、ジョブ失敗時はリトライ上限付きで再実行する。上限到達時は失敗として履歴に記録し、ユーザーへ再実行導線を提示する。
- LLMプロバイダの障害時は、規則辞書のみによるテンプレート合成（LLM精緻化なし）へ縮退して稼働を継続する。縮退で生成された案にはその旨を明記する。

### 5.2 セキュリティ

- 認証はXログイン（OAuth 2.0 + PKCE）とする。
- 開発者用管理画面はBASIC認証とする。
- 生成リクエストのフォームにreCAPTCHAを適用する。
- APIキー・照合先アカウントID等の秘匿値はすべて環境変数で外部化する。
- LLMへ送信する入力はユーザーの入力条件のみとし、認証情報・個人識別子を含めない。

### 5.3 個人情報

プライバシーポリシー・個人情報管理規程に従い設計する。保持する個人関連情報はXのユーザーID（識別子）と表示名のみとし、メールアドレス・住所・電話番号は取得しない。

## 6. 認証・アクセス制御

- 指定Xアカウントのフォロワーであることを利用条件とする。
- フォロワーIDリストをサーバー側にキャッシュし、認証で取得したユーザーIDと照合して判定する。初回のみ全件取得し、以降は差分取得とする（ログインのたびにX APIを呼び出さない）。
- 照合先アカウントIDは環境変数で外部化する。
- 判定結果は**プラン値**（単一項目）としてユーザーに保持し、機能側はプラン値のみを参照する。フォロー判定の有無から機能側が直接判定しない。判定手段を変更・廃止しても機能側の実装に影響を与えないことを設計上の要件とする。
- フォロー直後の判定漏れに対して、ユーザー操作による手動再判定の導線を設ける。再判定にはクールダウン（レート制限保護）を必須とする。
- X APIの障害時はキャッシュを正とし、新規判定のみ停止する。既存ユーザーを締め出さない。

## 7. 運用要件（測定・保守・監視）

### 7.1 測定（測定軸のみを定義する）

- 生成リクエスト数（ユーザー別・業種別・スタイル別・モデル別）
- バリエーション3案のうちコピーされた案の分布（構図タイプ別の採用傾向）
- プロンプト評価メモの記録率と評価傾向
- 再生成率（同一プロジェクトでの条件変更回数）
- 縮退モードでの生成比率
- 上限到達の発生数（クォータ到達により生成できなかったアクセス数。追加需要の観測に用いる）
- クォータ返還の発生数（生成失敗の間接指標）
- 稼働率

### 7.2 保守

- 生成モデル各社の仕様変更（パラメータ記法・ネガティブプロンプト対応の変更）に追随し、モデルアダプタと規則辞書を改訂する。
- 規則辞書は管理画面から無停止で更新可能とし、辞書のバージョンを生成履歴に記録する。
- 不具合対応・機能改修のリリースフローを定義し、DBマイグレーションは後方互換を保って段階適用する。

### 7.3 監視

- ヘルスチェック用エンドポイントを設け、DB到達性を含めて応答する。
- 死活監視は外形監視サービス（無料枠のあるもの）またはデプロイ先の標準機能で行い、監視スタックを別途構築しない。
- 通知先を定義し、通知が復旧行動に繋がる体制（担当・一次対応手順）を運用文書に明記する。
- LLMジョブの失敗率・縮退モード発生をアラート対象とする。
- X APIのエラー率を監視し、フォロワーキャッシュの差分取得失敗を検知する。

## 8. ER図

```mermaid
erDiagram
    users ||--o{ projects : owns
    users ||--o{ presets : owns
    users ||--o{ quota_consumptions : consumes
    users ||--|| follower_checks : has
    projects ||--o{ prompt_requests : contains
    prompt_requests ||--o{ prompt_outputs : produces
    prompt_outputs ||--o{ evaluation_notes : receives
    rule_dictionaries ||--o{ prompt_requests : "applied (version)"

    users {
        bigint id PK
        string x_user_id UK "XのユーザーID"
        string display_name "Xの表示名"
        string plan "プラン値(アクセス権)"
        datetime created_at
    }
    follower_checks {
        bigint id PK
        bigint user_id FK
        boolean is_follower
        datetime checked_at
        datetime cooldown_until "手動再判定のクールダウン"
    }
    projects {
        bigint id PK
        bigint user_id FK
        string name "サイト名(任意)"
        string industry
        string style_family
        jsonb brand_settings "トーン・カラー等"
        datetime created_at
    }
    presets {
        bigint id PK
        bigint user_id FK
        string name
        jsonb input_conditions
    }
    prompt_requests {
        bigint id PK
        bigint project_id FK
        jsonb inputs "正規化済み入力"
        string target_model
        string status "状態遷移図参照"
        string dictionary_version
        boolean degraded "縮退モード生成か"
        datetime created_at
    }
    prompt_outputs {
        bigint id PK
        bigint prompt_request_id FK
        int variation_no "1..3"
        string composition_type "被写体主導/環境主導/抽象背景"
        text main_prompt
        text negative_prompt
        jsonb parameters
        text art_direction_note
    }
    evaluation_notes {
        bigint id PK
        bigint prompt_output_id FK
        int rating
        text memo
        datetime created_at
    }
    quota_consumptions {
        bigint id PK
        bigint user_id FK "user_id×quota_dayで一意"
        date quota_day "JST03:00境界の日付"
        bigint prompt_request_id FK
        string status "reserved / confirmed / refunded"
        boolean reset_by_admin "手動リセットの記録"
        datetime created_at
    }
    rule_dictionaries {
        bigint id PK
        string version UK
        jsonb anti_ai_rules "クリシェ排除規則"
        jsonb style_spec_rules "スタイル仕様化規則"
        jsonb industry_defaults "業種既定値"
        datetime published_at
    }
```

## 9. DFD

### 9.1 レベル0（コンテキスト図）

```mermaid
flowchart LR
    U[ユーザー<br>サイト制作者] -->|入力条件| S((hero-prompt-forge))
    S -->|プロンプトパッケージ| U
    A[管理者] -->|規則辞書の更新| S
    S -->|フォロワー照合| X[X API]
    X -->|フォロワーID差分| S
    S -->|精緻化要求| L[LLMプロバイダ]
    L -->|精緻化結果| S
```

### 9.2 レベル1

```mermaid
flowchart TB
    U[ユーザー] -->|1 認証| P1[認証・プラン判定]
    P1 <-->|照合| D1[(users / follower_checks)]
    P1 -->|差分取得| X[X API]
    U -->|2 入力条件| P2[入力検証・正規化]
    P2 -->|禁止入力| U
    P2 -->|正規化入力| P3[規則適用・矛盾解決]
    D2[(rule_dictionaries)] --> P3
    P3 --> P4[モデル別整形・バリエーション展開]
    P4 -->|精緻化ジョブ| P5[LLM精緻化 非同期]
    P5 <--> L[LLMプロバイダ]
    P5 -->|失敗時| P6[縮退合成]
    P5 --> D3[(prompt_requests / prompt_outputs)]
    P6 --> D3
    D3 -->|3 パッケージ表示| U
    U -->|4 評価メモ| D4[(evaluation_notes)]
```

## 10. シーケンス図

### 10.1 ログインとフォロワー判定

```mermaid
sequenceDiagram
    actor User as ユーザー
    participant FE as Next.js
    participant BE as Rails API
    participant DB as PostgreSQL
    participant X as X API

    User->>FE: ログイン操作
    FE->>X: OAuth 2.0 + PKCE 認可要求
    X-->>FE: 認可コード
    FE->>BE: コード引き渡し
    BE->>X: トークン交換・ユーザーID取得
    BE->>DB: フォロワーキャッシュ照合
    alt キャッシュにIDあり
        BE->>DB: プラン値を有効に設定
    else キャッシュにIDなし
        BE-->>FE: 未フォロー案内＋手動再判定導線
    end
    BE-->>FE: セッション確立・プラン値返却
    Note over BE,X: X API障害時はキャッシュを正とし<br>新規判定のみ停止する
```

### 10.2 プロンプト生成

```mermaid
sequenceDiagram
    actor User as ユーザー
    participant FE as Next.js
    participant BE as Rails API
    participant Q as 非同期ジョブ
    participant LLM as LLMプロバイダ
    participant DB as PostgreSQL

    User->>FE: 入力条件送信(reCAPTCHA)
    FE->>BE: 生成リクエスト
    BE->>BE: 入力検証・正規化・禁止入力検出
    BE->>DB: クォータ予約(ユーザー×クォータ日で一意)
    alt 本日分消費済み
        BE-->>FE: 上限到達・次回リセット時刻(JST03:00)を提示
    end
    BE->>DB: prompt_requests作成(status=queued)
    BE->>Q: ジョブ投入
    BE-->>FE: リクエストID返却
    Q->>DB: 規則辞書読込
    Q->>Q: 規則適用・矛盾解決・モデル整形・3案展開
    Q->>LLM: 表現の精緻化
    alt 成功
        LLM-->>Q: 精緻化結果
    else リトライ上限到達
        Q->>Q: 縮退合成(辞書のみ)・degraded=true
    end
    Q->>DB: prompt_outputs保存(status=completed)
    Note over Q,DB: 完了(縮退含む)でクォータ確定<br>縮退も失敗した場合はクォータを返還
    FE->>BE: 結果ポーリング
    BE-->>FE: プロンプトパッケージ
    FE-->>User: 3案表示・コピー・評価メモ
```

## 11. クラス図

```mermaid
classDiagram
    class PromptGenerationService {
        +generate(inputs) PromptPackage
    }
    class InputNormalizer {
        +validate(raw) NormalizedInput
        +applyDefaults(input) NormalizedInput
        +detectForbidden(input) ForbiddenError
    }
    class RuleEngine {
        -dictionaryVersion
        +applyAntiAiRules(input) RuledDraft
        +applyStyleSpecs(draft) RuledDraft
    }
    class ConflictResolver {
        +resolve(draft) RuledDraft
        %% 優先順位: コピースペース>カラー>スタイル>トーン
    }
    class VariationExpander {
        +expand(draft) Draft[3]
    }
    class ModelAdapter {
        <<interface>>
        +format(draft) PromptOutput
    }
    class MidjourneyAdapter
    class DalleAdapter
    class StableDiffusionAdapter
    class NanoBananaAdapter
    class LlmRefiner {
        +refine(output) PromptOutput
        +fallback(output) PromptOutput
    }
    class AuthService {
        +loginWithX(code) Session
        +recheckFollow(userId) PlanValue
    }
    class FollowerCacheService {
        +syncDiff() void
        +isFollower(xUserId) bool
    }
    class PlanValue {
        +authorized bool
    }

    PromptGenerationService --> InputNormalizer
    PromptGenerationService --> RuleEngine
    PromptGenerationService --> ConflictResolver
    PromptGenerationService --> VariationExpander
    PromptGenerationService --> ModelAdapter
    PromptGenerationService --> LlmRefiner
    ModelAdapter <|.. MidjourneyAdapter
    ModelAdapter <|.. DalleAdapter
    ModelAdapter <|.. StableDiffusionAdapter
    ModelAdapter <|.. NanoBananaAdapter
    AuthService --> FollowerCacheService
    AuthService --> PlanValue
```

## 12. 状態遷移図

### 12.1 プロンプトリクエストの状態

```mermaid
stateDiagram-v2
    [*] --> draft : 入力開始
    draft --> queued : 検証通過・ジョブ投入
    draft --> rejected : 禁止入力検出
    queued --> generating : ジョブ開始
    generating --> completed : 3案生成完了
    generating --> degraded_completed : LLM失敗→縮退合成で完了
    generating --> failed : 縮退も失敗
    failed --> queued : ユーザー再実行
    completed --> archived : プロジェクト整理
    degraded_completed --> archived : プロジェクト整理
    rejected --> [*]
    archived --> [*]
```

**クォータとの対応**：`queued` への遷移時に予約消費し、`completed`／`degraded_completed` で確定、`failed` で返還する。`rejected` は消費しない。`failed → queued` の再実行は同一リクエストの再実行であり、追加消費しない。

### 12.2 ユーザーのアクセス権（プラン値）の状態

```mermaid
stateDiagram-v2
    [*] --> unverified : 初回ログイン
    unverified --> active : フォロワー照合一致
    unverified --> pending : 照合不一致(未フォロー)
    pending --> active : 手動再判定で一致
    pending --> pending : 再判定不一致(クールダウン)
    active --> active : X API障害時もキャッシュを正とし維持
```

## 13. ユースケース図

```mermaid
flowchart LR
    subgraph system[hero-prompt-forge]
        UC1((プロンプト<br>パッケージを生成する))
        UC2((バリエーションを<br>比較しコピーする))
        UC3((プリセットを<br>保存・呼び出す))
        UC4((評価メモを記録する))
        UC5((手動再判定を行う))
        UC6((規則辞書を更新する))
        UC7((ユーザー・プラン値を<br>管理する))
        UC8((利用状況を集計する))
        UC10((クォータを<br>手動リセットする))
    end
    User[ユーザー<br>サイト制作者] --- UC1
    User --- UC2
    User --- UC3
    User --- UC4
    User --- UC5
    Admin[管理者] --- UC6
    Admin --- UC7
    Admin --- UC8
    Admin --- UC10
    UC1 -.include.-> UC9((Xログイン・<br>フォロワー判定))
    User --- UC9
```
