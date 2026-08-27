# ER 図

**実装から起こした図です。** 正は `src/backend/db/schema.rb` です。

**待ち行列とキャッシュの表（`solid_queue_*` ・ `solid_cache_entries`）は載せません。** Rails の仕組みが持つ表で、業務の意味を持たないためです。

```mermaid
erDiagram
    users ||--o{ sessions : "ログインのたびに作ります"
    users ||--o{ projects : "所有します"
    users ||--o{ presets : "保存します"
    users ||--o{ quota_consumptions : "1 日 1 件です"
    users ||--o{ admin_actions : "管理の操作の対象です"
    projects ||--o{ prompt_requests : "生成のお申し込みです"
    prompt_requests ||--o{ prompt_outputs : "3 案を持ちます"
    prompt_requests |o--o| quota_consumptions : "予約を結び付けます"
    prompt_outputs ||--o| evaluation_notes : "1 案につき 1 件です"

    users {
        bigint id PK
        string x_user_id UK "X の数値のユーザーID"
        string display_name "X の表示名"
        string plan "アクセス権を表す単一項目"
        datetime plan_checked_at "最後に判定した時刻"
        datetime recheck_available_at "次に手動再判定を要求できる時刻"
    }

    sessions {
        bigint id PK
        bigint user_id FK
        string token_digest UK "セッション識別子のハッシュ"
        datetime expires_at "失効する時刻"
        datetime revoked_at "取り消した時刻"
    }

    projects {
        bigint id PK
        bigint user_id FK
        string industry "業種"
        string style_family "スタイル系統"
        string name "サイト名（任意）"
        jsonb brand_settings "トーン・カラー等"
    }

    presets {
        bigint id PK
        bigint user_id FK
        string name "プリセット名（利用者ごとに一意です）"
        jsonb input_conditions "入力条件の組み合わせ"
    }

    prompt_requests {
        bigint id PK
        bigint project_id FK
        string status "状態遷移図を参照します"
        string target_model "生成モデル"
        jsonb inputs "正規化済み入力"
        boolean degraded "縮退モードで生成したか"
        string dictionary_version "適用した規則辞書の版"
        text rejection_reason "差し戻した理由"
    }

    prompt_outputs {
        bigint id PK
        bigint prompt_request_id FK
        integer variation_no "1 〜 3（お申し込みごとに一意です）"
        string composition_type "被写体主導／環境主導／抽象背景"
        text main_prompt "メインプロンプト"
        text negative_prompt "対応しないモデルでは空です"
        jsonb parameters "推奨パラメータ"
        text art_direction_note "アートディレクションノート"
    }

    evaluation_notes {
        bigint id PK
        bigint prompt_output_id UK "1 案につき 1 件です"
        integer rating "5 段階。未評価は空です"
        text memo "所感"
    }

    quota_consumptions {
        bigint id PK
        bigint user_id FK
        bigint prompt_request_id FK "予約の対象"
        date quota_day "JST 3:00 を境界とする日付"
        string status "reserved / confirmed / refunded"
        boolean reset_by_admin "管理者による手動リセットか"
    }

    admin_actions {
        bigint id PK
        bigint user_id FK "対象が無い操作では空です"
        string actor "実施者（管理画面の利用者名）"
        string action "操作の種別"
        jsonb details "補足。秘匿値を入れません"
    }

    rule_dictionaries {
        bigint id PK
        string version UK "版の識別子"
        jsonb anti_ai_rules "クリシェ排除規則"
        jsonb style_spec_rules "スタイル仕様化規則"
        jsonb industry_defaults "業種既定値"
        datetime published_at "未公開は空です"
    }

    metric_events {
        bigint id PK
        string axis "測定軸の名前"
        date occurred_on "クォータ日"
        integer occurrences "その日の件数"
    }
```

## 読み取りの要点

**`rule_dictionaries` と `metric_events` は、どの表とも外部キーで結び付きません。**

- `rule_dictionaries` は版として積み上げます。**公開済みの版を書き換えません。** どの版を使ったかは `prompt_requests.dictionary_version` が文字列で持ちます。**外部キーにしません。** 版が消えても、当時どの版で作ったかの記録は残す必要があるためです。
- `metric_events` は日ごとの件数だけを持ちます。**誰の分かを持ちません**（`requirements.md` 7.1）。

**`quota_consumptions` は、利用者とクォータ日の組で一意です。** 同じ日に 2 件作れません。**予約中（`reserved`）の行は、1 つのお申し込みにつき 1 件だけ**という部分一意の索引も持ちます。

**`prompt_requests` と `quota_consumptions` の結び付きは、後から付きます。** 枠の予約は、お申し込みの行を作る前に行うためです（`prompt_request_id` は空を許します）。

**利用者を消す経路はありません。** 生成履歴が結び付いているためです。
