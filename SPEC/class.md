# クラス図

**実装から起こした図です。** 主要な持ち場だけを載せます。すべてのクラスを網羅しません。

## 生成の組み立て

```mermaid
classDiagram
    class PromptGenerationService {
        +call(prompt_request) PromptPackage[]
    }
    class StyleSpec {
        +decide(inputs, dictionary) 仕様
    }
    class Draft {
        +build(仕様) 素材
    }
    class LlmRefiner {
        +refine(素材) 素材
    }
    class DegradedComposer {
        +compose(仕様) 素材
    }
    class ModelAdapter {
        <<abstract>>
        +format(素材) PromptPackage
    }
    class MidjourneyAdapter
    class DalleAdapter
    class StableDiffusionAdapter
    class NanoBananaAdapter
    class NarrativeAdapter {
        <<mixin>>
        +自然文へ組み立てます
    }
    class TermRoles {
        +役割ごとの述語を決めます
    }
    class PromptPackage {
        +main_prompt
        +negative_prompt
        +parameters
        +art_direction_note
    }

    PromptGenerationService --> StyleSpec
    PromptGenerationService --> Draft
    PromptGenerationService --> LlmRefiner
    PromptGenerationService --> DegradedComposer
    PromptGenerationService --> ModelAdapter
    ModelAdapter <|-- MidjourneyAdapter
    ModelAdapter <|-- DalleAdapter
    ModelAdapter <|-- StableDiffusionAdapter
    ModelAdapter <|-- NanoBananaAdapter
    DalleAdapter ..> NarrativeAdapter
    NanoBananaAdapter ..> NarrativeAdapter
    NarrativeAdapter --> TermRoles
    ModelAdapter --> PromptPackage
```

**生成モデルごとの違いは、整形の持ち場に閉じます。** 語を並べるモデル（Midjourney ・ Stable Diffusion）と、自然文で述べるモデル（DALL·E ・ nano banana）で、整形だけが変わります。

**素材の役割は控えから受け取ります**（`TermRoles`）。素材の文字列を照合して見分けません。言い回しが変わったときに黙って外れるためです。

## LLM の呼び出し

```mermaid
classDiagram
    class LlmRefiner {
        +refine(素材)
    }
    class GeminiClient {
        +refine(instruction, lines) String[]
    }
    class LangchainGemini {
        +http_post(url, params)
        -呼び出し先を設定から決めます
        -鍵を見出しで送ります
        -待ち時間の上限を設けます
    }
    class LlmSettings {
        +load() Hash
        -暗号化された呼び出し先だけを認めます
    }
    class GoogleGemini {
        <<langchainrb>>
    }

    LlmRefiner --> GeminiClient
    GeminiClient --> LangchainGemini
    GeminiClient --> LlmSettings
    GoogleGemini <|-- LangchainGemini
```

**上書きするのは 3 点だけです。** 呼び出し先・鍵の送り方・待ち時間です。**そのほかは gem に委ねます。**

## 認証とアクセス制御

```mermaid
classDiagram
    class AuthenticatesUser {
        <<concern>>
        +current_user
        -開発では自動ログインへ分岐します
    }
    class AuthenticatesAdmin {
        <<concern>>
        +admin_actor
    }
    class VerifiesHumans {
        <<concern>>
        +verify_human!
    }
    class AdminCredentials {
        +from_env() Credentials
        +actor_for(name, password) String
    }
    class RecaptchaVerifier {
        +call(token) Float
    }
    class AppEnvironment {
        +current
        +developer_shortcuts_allowed?
    }
    class Session {
        +find_alive(token)
        +revoke!
    }
    class FollowerGateClient {
        +decide(x_user_id) Decision
    }

    AuthenticatesUser --> Session
    AuthenticatesUser --> AppEnvironment
    AuthenticatesAdmin --> AdminCredentials
    VerifiesHumans --> RecaptchaVerifier
    VerifiesHumans --> AppEnvironment
```

**環境ごとの分岐は `AppEnvironment` を必ず通します。** 環境変数を各所で直に読むと、判定の条件が散らばって追えなくなります。**未設定・未知の値は例外にします。**

**管理画面の照合と実施者の決定は、1 つの返り値にまとめます。** 通らなかった名前を実施者として控えられません。

## クォータ（1 日の生成枠）

```mermaid
classDiagram
    class Reservation {
        +reserve!(user, prompt_request)
        +settle!(prompt_request)
        +refund!(prompt_request)
    }
    class QuotaDay {
        +of(time) Date
        -JST 3:00 を境界とします
    }
    class QuotaConsumption {
        +status
        +quota_day
        +outstanding
    }

    Reservation --> QuotaDay
    Reservation --> QuotaConsumption
```

## 生成の投入と拾い直し

```mermaid
classDiagram
    class GeneratePromptJob {
        +perform(prompt_request_id)
        -claimed?(request)
        -stale?(request)
    }
    class ReclaimPromptRequestsJob {
        +perform()
        -stale_ids()
        -unsettled_ids()
    }
    class Delivery {
        +store(request, packages)
    }

    ReclaimPromptRequestsJob ..> GeneratePromptJob : 投入し直します
    GeneratePromptJob --> Delivery
```

**置き去りと見なすまでの時間は、両方の持ち場で同じ値です。** 書き写さず、片方から引きます。片方だけを直すと、拾い直しが黙って発火しなくなります。
