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
  #
  # **対象は、コピースペースの段が使う印そのものを見ます。**
  # 同じ文字列をここへ書き写すと、言い回しが変わったときに、**例外もノートも
  # 残さないまま重みが消えます**（PR #154 のレビューより）。
  class StableDiffusionAdapter < ModelAdapter
    MODEL_KEY = 'stable_diffusion'

    # 記法が必ず持つ鍵です。
    REQUIRED_KEYS = %w[term_separator emphasis_weight].freeze

    # 重み付けの対象を見分ける印です。**コピースペースの段と同じものを見ます。**
    EMPHASIS_MARK = Generation::CopySpace::RESERVED_MARK

    # **この記法で特別な意味を持つ文字です。**
    # 素材に混ざると、入れ子の強調・別の重み指定として解釈され、
    # 意図しない強さになります。
    RESERVED_CHARACTERS = /[()]|:/

    class << self
      def model_key = MODEL_KEY

      def required_keys = REQUIRED_KEYS
    end

    # **打ち消しの欄を持ちます。**
    def negative_prompt?
      true
    end

    private

    def main_prompt_for(draft)
      draft.main_terms.map { |term| weighted(term) }.join(rules.fetch('term_separator'))
    end

    # 最上位の指示にだけ重みを付けます。
    def weighted(term)
      return term unless term.include?(EMPHASIS_MARK)

      ensure_weightable!(term)
      "(#{term}:#{rules.fetch('emphasis_weight')})"
    end

    # **記法を壊す文字が混ざったら、その場で失敗させます。**
    # 退避させて進めると、利用者は意図しない強さの絵を受け取ります。
    def ensure_weightable!(term)
      return unless term.match?(RESERVED_CHARACTERS)

      raise UnsafeTermError,
            "重みを付ける素材に、記法で意味を持つ文字が含まれます: #{term}" # 開発者向け
    end

    def negative_prompt_for(draft)
      joined_negative_terms(draft)
    end

    def parameters_for(draft)
      { ASPECT_RATIO_PARAMETER => input_value(draft, :aspect_ratio) }
    end
  end
end
