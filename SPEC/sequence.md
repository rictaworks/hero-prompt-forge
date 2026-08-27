# シーケンス図

**実装から起こした図です。** 実際の経路だけを載せます。

## 1. X でログインします

```mermaid
sequenceDiagram
    autonumber
    actor 利用者
    participant 画面 as 画面（Next.js）
    participant API as API（Rails）
    participant X as X（OAuth 2.0 + PKCE）
    participant Gate as x-follower-gate
    participant DB as PostgreSQL

    利用者->>画面: 「X でログイン」を押します
    画面->>API: GET /auth/start
    API->>API: 認可の途中の値を作ります（PKCE）
    API-->>利用者: X の認可画面へ送ります（Cookie に途中の値）
    利用者->>X: 認可します
    X-->>API: GET /auth/callback（引換券）
    API->>X: 引換券を交換します
    X-->>API: ユーザー ID ・ 表示名
    API->>Gate: このユーザー ID はフォロワーですか
    Gate-->>API: 判定
    API->>DB: 利用者を作る／更新します（プラン値）
    API->>DB: セッションを作ります（識別子のハッシュ）
    API-->>利用者: 画面へ戻します（Cookie に hpf_session）
```

**Cookie は 2 つです。** 認可の途中の値（短命）と、セッション（`hpf_session`）です。**セッションの識別子そのものは保存しません。** ハッシュだけを持ちます。

**フォロワー判定を自前で作りません**（`requirements.md` 6）。判定サービスへ問い合わせ、**結果はプラン値という 1 つの項目に落とします。**

## 2. 生成をお申し込みします

```mermaid
sequenceDiagram
    autonumber
    actor 利用者
    participant 画面 as 画面（Next.js）
    participant API as API（Rails）
    participant Google as reCAPTCHA
    participant DB as PostgreSQL
    participant 働き手 as 生成の働き手

    利用者->>画面: 条件を入れて「生成する」を押します
    画面->>Google: 合図を取ります（v3）
    Google-->>画面: 合図
    画面->>API: POST /api/v1/prompt_requests（合図を見出しに載せます）
    API->>Google: 合図を照合します
    Google-->>API: 得点
    API->>API: 入力を正規化します
    API->>API: 禁止入力を探します

    alt 禁止入力が見つかりました
        API->>DB: 差し戻しとして記録します（枠を使いません）
        API-->>画面: 422（理由と直し方）
        画面-->>利用者: 差し戻しの画面（入力の写しに印）
    else 見つかりません
        API->>DB: 本日の枠を予約します
        API->>DB: お申し込みを作ります
        API->>働き手: 生成の仕事を投入します
        API-->>画面: 201（お申し込みの識別子）
        画面-->>利用者: 生成中の画面
    end
```

**合図の照合は、本番では必ず行います。** 開発では、秘密鍵が設定されているときだけ行います。

**枠の予約は、お申し込みの行を作る前です。** 予約できなければ、そこで止めます（上限到達）。

## 3. 3 案ができるまで

```mermaid
sequenceDiagram
    autonumber
    participant 働き手 as 生成の働き手
    participant DB as PostgreSQL
    participant Gemini as Gemini（LangChain 経由）

    働き手->>DB: お申し込みを掴みます（generating へ）
    働き手->>DB: 公開済みの最新の規則辞書を読みます
    働き手->>働き手: スタイルを仕様化します
    働き手->>働き手: 3 案の素材を組み立てます

    alt 鍵があり、呼び出しが通りました
        働き手->>Gemini: 素材の英文を磨きます
        Gemini-->>働き手: 磨いた英文
    else 鍵が無い／呼び出しが失敗しました
        働き手->>働き手: 規則辞書だけで組み立てます（縮退）
    end

    働き手->>働き手: 生成モデルごとに整えます
    働き手->>DB: 3 案を収めます（completed / degraded_completed）
    働き手->>DB: 枠を確定します
```

**働き手が異常終了した場合は、定時の拾い直し（5 分ごと）が拾い直します。**

## 4. 進み具合を見て、3 案を受け取ります

```mermaid
sequenceDiagram
    autonumber
    actor 利用者
    participant 画面 as 画面（Next.js）
    participant API as API（Rails）
    participant DB as PostgreSQL

    loop 出来上がるまで
        画面->>API: GET /api/v1/prompt_requests/:id
        API->>DB: 状態を読みます
        API-->>画面: 状態（＋できていれば 3 案）
        画面-->>利用者: 進み具合
    end

    利用者->>画面: 結果の画面を開きます
    画面-->>利用者: 3 案（メイン／ネガティブ／パラメータ／ノート）
    利用者->>画面: 「コピー」を押します
    画面-->>利用者: 写し取りました
```

**縮退で作った案には、その旨を出します。**

## 5. 評価メモを残します

```mermaid
sequenceDiagram
    autonumber
    actor 利用者
    participant 画面 as 画面（Next.js）
    participant API as API（Rails）
    participant DB as PostgreSQL

    利用者->>画面: 評価メモの画面を開きます
    画面->>API: GET /api/v1/prompt_outputs/:id/evaluation_note
    API-->>画面: 既存のメモ（無ければ空です）
    利用者->>画面: 5 段階と所感を入れます
    画面->>API: POST（初回）／ PATCH（2 回目以降）
    API->>DB: 記録します（案 1 つにつき 1 件です）
    API-->>画面: 記録した内容
```

**上限に達していても記録できます。** 評価メモは枠を使いません。

## 6. 管理者が本日の枠をリセットします

```mermaid
sequenceDiagram
    autonumber
    actor 管理者
    participant 管理画面 as 管理画面（Rails）
    participant DB as PostgreSQL

    管理者->>管理画面: BASIC 認証を通ります
    管理画面->>管理画面: 通った利用者名だけを実施者にします
    管理者->>管理画面: 利用者の画面で「本日の枠をリセットする」を押します
    管理画面->>DB: 本日の消費を確かめます

    alt 消費があります
        管理画面->>DB: リセットします（reset_by_admin）
        管理画面->>DB: 管理の操作を記録します（実施者・日時）
        管理画面-->>管理者: リセットしました
    else 消費がありません
        管理画面-->>管理者: リセットは要りません（記録も残しません）
    end
```

**通らなかった資格情報の名前は、実施者として控えません。**
