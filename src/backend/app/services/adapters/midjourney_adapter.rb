# frozen_string_literal: true

module Adapters
  # Midjourney 系の記法です（requirements.md 4.1 の 7）。
  #
  # **語をカンマで並べ、パラメータを本文の末尾へ付けます。**
  # 打ち消しは `--no` に並べます。**別の欄を持ちません。**
  #
  #   a calm office, 35mm lens, clear copy space --ar 16:9 --no deformed hands
  #
  # **パラメータは本文の最後に置きます。** 途中に置くと効きません。
  #
  # **打ち消しが 1 件も無ければ `--no` を付けません。**
  # 値の無い `--no` は受け付けられません（PR #154 のレビューより）。
  class MidjourneyAdapter < ModelAdapter
    MODEL_KEY = 'midjourney'

    # 記法が必ず持つ鍵です。
    REQUIRED_KEYS = %w[term_separator aspect_ratio_parameter negative_parameter].freeze

    # パラメータの区切りです。
    PARAMETER_SEPARATOR = ' '

    class << self
      def model_key = MODEL_KEY

      def required_keys = REQUIRED_KEYS
    end

    # **打ち消しは、パラメータの中に置きます。専用の欄ではありません。**
    def negative_prompt?
      true
    end

    private

    def main_prompt_for(draft)
      draft.main_terms.join(rules.fetch('term_separator'))
    end

    def negative_prompt_for(draft)
      joined_negative_terms(draft)
    end

    # **鍵の名前はモデル共通です。** `--ar` のような記法の断片を、
    # 受け取る側へ持ち込みません。
    def parameters_for(draft)
      { ASPECT_RATIO_PARAMETER => input_value(draft, :aspect_ratio) }
    end

    # **本文の末尾へパラメータを付けた、貼り付けられる形を返します。**
    def prompt_for(draft, main_prompt)
      [main_prompt, *parameter_tokens(draft)].join(PARAMETER_SEPARATOR)
    end

    def parameter_tokens(draft)
      tokens = [rules.fetch('aspect_ratio_parameter'), input_value(draft, :aspect_ratio)]
      negative = joined_negative_terms(draft)
      return tokens if negative.nil?

      tokens + [rules.fetch('negative_parameter'), negative]
    end
  end
end
