# API 契約

フロントエンドとバックエンドが共通で守る決まりです。**実装したエンドポイントのみを記載します。**

## 共通の決まり

| 項目 | 決まり |
|---|---|
| 基底パス | `/api/v1` |
| 形式 | `application/json`（UTF-8） |
| 日時 | ISO 8601・**JST**（例 `2026-08-25T10:30:00+09:00`） |
| 命名 | 項目名は `snake_case` です |
| 認証 | セッションによります。未認証は `401` を返します |
| プラン値 | 権限が足りない場合は `403` を返します |

## 成功の応答

本体をそのまま返します。包み込みません。

```json
{ "id": 1, "status": "queued", "created_at": "2026-08-25T10:30:00+09:00" }
```

## 失敗の応答

**すべての失敗で同じ形を返します。** 曖昧なエラーを返しません。利用者に見せる文言と、次に行う操作を必ず含めます。

```json
{
  "error": {
    "code": "quota_exhausted",
    "message": "本日の生成枠を使い切りました。",
    "next_action": "次回のリセットは 8月26日 03:00 です。それまでお待ちください。",
    "details": { "reset_at": "2026-08-26T03:00:00+09:00" }
  }
}
```

| 項目 | 必須 | 内容 |
|---|---|---|
| `code` | ○ | 機械が判定するための識別子です。`snake_case` です |
| `message` | ○ | 利用者に見せる文言です。ですます調で書きます |
| `next_action` | ○ | 次に行う操作です。分からない場合でも空にしません |
| `details` | − | 補足です。個人情報・秘匿値を入れません（下の例外を除きます） |

**`details` の例外**：**要求した本人が送った入力の写しは含めます。** どこを直せばよいかが分からないと、1000 文字の文章を直せないためです。応答は要求した本人にだけ返り、**記録には残しません。** 第三者の情報・他の利用者の情報・秘匿値は、いかなる場合も含めません。

**画面側は、この写しを描くときに必ず逃がしてください（エスケープ）。** 利用者が送った文字がそのまま返ります。

## 状態コード

| コード | 用いる場面 |
|---|---|
| `200` | 取得・更新に成功した場合 |
| `201` | 作成に成功した場合 |
| `400` | 入力が不正な場合 |
| `401` | 未認証の場合 |
| `403` | 権限が足りない場合 |
| `404` | 対象が存在しない、または他人の資源の場合 |
| `422` | 入力は形式として正しいが、規則により受け付けられない場合 |
| `429` | 回数の上限に達した場合 |
| `503` | 依存する仕組みが応答しない場合 |

**他人の資源へは `403` ではなく `404` を返します。** 存在の有無を知らせないためです。

## 実装済みのエンドポイント

エンドポイントを実装した issue で、この表へ追記します。

| 種別 | パス | 概要 | 仕様 |
|---|---|---|---|
| `GET` | `/api/v1/projects` | プロジェクトの一覧です | 下記 |
| `POST` | `/api/v1/projects` | プロジェクトを作ります | 下記 |
| `PATCH` | `/api/v1/projects/:id` | プロジェクトを更新します | 下記 |
| `GET` | `/api/v1/presets` | プリセットの一覧です | 下記 |
| `GET` | `/api/v1/presets/:id` | プリセットを呼び出します | 下記 |
| `POST` | `/api/v1/presets` | プリセットを保存します | 下記 |
| `PATCH` | `/api/v1/presets/:id` | プリセットを更新します | 下記 |
| `GET` | `/api/v1/prompt_requests` | 生成履歴の一覧です | 下記 |
| `POST` | `/api/v1/prompt_requests` | 生成リクエストを受け付けます | 下記 |
| `GET` | `/api/v1/prompt_requests/:id` | 状態と、完了していれば 3 案を返します | 下記 |
| `GET` | `/api/v1/prompt_outputs/:prompt_output_id/evaluation_note` | 評価メモを取り出します | 下記 |
| `POST` | `/api/v1/prompt_outputs/:prompt_output_id/evaluation_note` | 評価メモを記録します | 下記 |
| `PATCH` | `/api/v1/prompt_outputs/:prompt_output_id/evaluation_note` | 評価メモを更新します | 下記 |

**いずれも認証が要ります。プラン値が有効でなければ `403` です。**

**他人の資源は、必ず `404` です。** 一覧には載らず、識別子を指定しても見つかりません。

### プロジェクト（`/api/v1/projects`）

**受け取る項目**：`project[name]` ・ `project[industry]`（必須）・ `project[style_family]`（必須）・ `project[brand_settings]`。

**`project[user_id]` は受け取りません。** 持ち主は、ログインしている利用者で決まります。

**消す経路を作りません。** 生成履歴が結び付いています。

### プリセット（`/api/v1/presets`）

**受け取る項目**：`preset[name]`（必須・50 文字まで）・ `preset[input_conditions]`。

`input_conditions` に置ける鍵は、入力条件の項目に限られます。**それ以外を含むと `400` です。**

**名前は利用者ごとに一意です。** 他の方と同じ名前は使えます。

### 生成履歴（`GET /api/v1/prompt_requests`）

**上限に達していても閲覧できます。** 閲覧は生成ではありません。

`project_id` で絞り込めます。**他人のプロジェクトの識別子を指定しても、何も返しません。**

**一覧に案そのものを載せません。** 件数（`outputs_count`）と縮退の印（`degraded`）を返します。案の取り出しは 1 件ずつ行います。

```json
{
  "prompt_requests": [
    {
      "id": 12,
      "status": "degraded_completed",
      "degraded": true,
      "target_model": "midjourney",
      "dictionary_version": "v1.0.0",
      "created_at": "2026-08-27T10:30:00+09:00",
      "updated_at": "2026-08-27T10:30:42+09:00",
      "outputs_count": 3
    }
  ]
}
```

### 評価メモ（`/api/v1/prompt_outputs/:prompt_output_id/evaluation_note`)

**上限に達していても記録できます。** 記録は生成ではありません。

**案 1 つにつき 1 件です。** すでにある案へ `POST` すると書き換えます。

**受け取る項目**：`evaluation_note[rating]`（1 〜 5）・ `evaluation_note[memo]`（2000 文字まで）。**どちらも無い場合は `400` です。**

### `POST /api/v1/prompt_requests`

生成リクエストを受け付け、**ジョブを投入して 201 を返します。** 生成そのものは裏で走ります。

**要求**

| 項目 | 必須 | 内容 |
|---|---|---|
| `project_id` | ○ | プロジェクトの識別子です。**他人のものは `404` です** |
| `inputs.industry` | ○ | 業種です |
| `inputs.style_family` | ○ | スタイル系統です |
| `inputs.target_model` | ○ | 生成モデルです |
| `inputs.brand_tone` | − | トーンです。省くと業種の標準を使います |
| `inputs.service_summary` | − | サービス概要です。1000 文字までです |
| `inputs.brand_colors` | − | ブランドカラーです。`#RRGGBB` を 2 つまでです |
| `inputs.copy_space_position` | − | 文字を置く余白の位置です。既定は `left` です |
| `inputs.aspect_ratio` | − | 画角です。既定は `16:9` です |

**応答（`201`）**

```json
{
  "id": 12,
  "status": "queued",
  "degraded": false,
  "target_model": "midjourney",
  "dictionary_version": null,
  "created_at": "2026-08-27T10:30:00+09:00",
  "updated_at": "2026-08-27T10:30:00+09:00"
}
```

**失敗**

| コード | `code` | 場面 |
|---|---|---|
| `400` | `invalid_input` | 入力に誤りがあります。`details.fields` に項目と理由を添えます |
| `401` | `unauthorized` | 未認証です |
| `403` | `forbidden` | プラン値が有効ではありません |
| `404` | `not_found` | プロジェクトが無い、または他人のものです |
| `422` | `forbidden_input` | 禁止入力です。**クォータを消費しません。** `details` の中身は下の表のとおりです |
| `429` | `quota_exhausted` | 本日の枠を使い切っています。**`details.reset_at` に次回のリセット時刻（JST 03:00）を添えます** |

**`422`（`forbidden_input`）の `details`**

| 項目 | 内容 |
|---|---|
| `prompt_request_id` | 差し戻した記録の識別子です。状態は `rejected` です |
| `reasons[].kind` | 種別です（`real_person` ・ `brand_logo` ・ `third_party_work`） |
| `reasons[].matched` | **見つかった語です。要求した本人が送った入力の写しです。** 記録には残しません |
| `reasons[].suggestion_key` | 直し方を引くための鍵です |

**差し戻した記録には、自由に書いていただいた `service_summary` を残しません。** 権利に触れると判定した文章ですので、実在の方のお名前や商標を含みます。**業種・スタイル系統といった選択肢の値は、入力し直していただくときの手がかりとして残します。**

### `GET /api/v1/prompt_requests/:id`

**応答（`200`）**

`status` は requirements.md 12.1 の名前をそのまま返します。

| 項目 | 返す場面 | 内容 |
|---|---|---|
| `status` | 常に | `draft` / `queued` / `generating` / `completed` / `degraded_completed` / `failed` / `rejected` / `archived` |
| `degraded` | 常に | **縮退で作った場合に `true` です** |
| `outputs` | `completed` ・ `degraded_completed` のみ | 3 案です。案ごとにも `degraded` が付きます |
| `failure` | `rejected` ・ `failed` のみ | 利用者へ見せる文言と、次に行う操作です |

```json
{
  "id": 12,
  "status": "degraded_completed",
  "degraded": true,
  "target_model": "midjourney",
  "dictionary_version": "v1.0.0",
  "created_at": "2026-08-27T10:30:00+09:00",
  "updated_at": "2026-08-27T10:30:42+09:00",
  "outputs": [
    {
      "variation_no": 1,
      "composition_type": "subject_led",
      "main_prompt": "...",
      "negative_prompt": "...",
      "parameters": { "aspect_ratio": "16:9" },
      "art_direction_note": { "checkpoints": [] },
      "degraded": true
    }
  ]
}
```

**失敗**

| コード | `code` | 場面 |
|---|---|---|
| `401` | `unauthorized` | 未認証です |
| `403` | `forbidden` | プラン値が有効ではありません |
| `404` | `not_found` | 無い、または他人のリクエストです |
