# frozen_string_literal: true

module Adapters
  # Stable Diffusion 系の記法です（requirements.md 4.1 の 7）。
  #
  # **語をカンマで並べ、重み付けを括弧で表します。**
  # `(term:1.2)` は、その語を強めます。
  #
  # **打ち消しは別の欄です。** 本文とは分けて渡します。
  #
  # **重み付けは、いちばん大事な指示にだけ付けます。**
  # すべてに付けると、相対的な強さが失われます。requirements.md 4.1 の 5 が
  # 定める優先順位のうち、**最上位のコピースペースの確保**に付けます。
  class StableDiffusionAdapter < ModelAdapter
    # 素材の区切りです。
    SEPARATOR = ', '
    # 強める重みです。
    EMPHASIS_WEIGHT = '1.2'
    # 重み付けの対象を見分ける語です。
    EMPHASIS_MARK = 'copy space'

    # **打ち消しの欄を持ちます。**
    def negative_prompt?
      true
    end

    private

    def main_prompt_for(draft)
      draft.main_terms.map { |term| weighted(term) }.join(SEPARATOR)
    end

    # 最上位の指示にだけ重みを付けます。
    def weighted(term)
      return term unless term.include?(EMPHASIS_MARK)

      "(#{term}:#{EMPHASIS_WEIGHT})"
    end

    def negative_prompt_for(draft)
      draft.negative_terms.join(SEPARATOR)
    end

    def parameters_for(draft)
      { 'aspect_ratio' => input_value(draft, :aspect_ratio) }
    end
  end
end
