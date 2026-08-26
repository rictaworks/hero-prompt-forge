# frozen_string_literal: true

module Adapters
  # nano banana 系（Gemini 系の画像生成）の記法です（requirements.md 4.1 の 7）。
  #
  # **自然文で書きます。** 組み立ては NarrativeAdapter が持ちます。
  #
  # **打ち消しの欄を持ちません。** 会話文で指示する作りで、負の指定を渡す項目が
  # ありません。同系統の Imagen でも、その項目は新しい版で廃止され、
  # 「出したいものを肯定形で書く」ことが案内されています（PR #154 のレビューより）。
  #
  # **欄を持つと偽ると、行き場の無い打ち消しを受け取った側が本文へ書き込みます。**
  # それは、DALL-E 系について避けている失敗そのものです。
  class NanoBananaAdapter < NarrativeAdapter
    MODEL_KEY = 'nano_banana'

    class << self
      def model_key = MODEL_KEY
    end

    # **打ち消しの欄を持ちません。**
    def negative_prompt?
      false
    end

    private

    def negative_prompt_for(_draft)
      nil
    end

    # **鍵の名前はモデル共通です。**
    def parameters_for(draft)
      { ASPECT_RATIO_PARAMETER => input_value(draft, :aspect_ratio) }
    end
  end
end
