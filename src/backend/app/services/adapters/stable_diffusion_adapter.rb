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

    # 控えに残す印です。
    EMPHASIS_NOTE_KIND = :emphasis_applied

    # **この記法で特別な意味を持つ文字です。**
    #
    # **丸括弧は、どこにあっても強調です**（A1111 系の記法では約 1.1 倍）。
    # 素材に 1 つ混ざるだけで、「最上位の指示にだけ重みを付ける」という
    # この段の判断が崩れます。**本文へ入るすべての素材で弾きます**
    # （PR #154 の 2 回目のレビューより）。
    RESERVED_CHARACTERS = /[()]/

    # **コロンは、括弧の中でだけ重みの区切りになります。**
    # 括弧の外では、ただの文字です。画面の比（`16:9`）を述べる素材が
    # コロンを含みますので、**重みを付ける素材でだけ弾きます。**
    WEIGHT_SEPARATOR = /:/

    class << self
      def model_key = MODEL_KEY

      def required_keys = REQUIRED_KEYS

      def reserved_characters = RESERVED_CHARACTERS
    end

    # **打ち消しの欄を持ちます。**
    def negative_prompt?
      true
    end

    private

    def main_prompt_for(draft)
      draft.main_terms.map { |term| weighted(term) }.join(rules.fetch('term_separator'))
    end

    # 当てた重みの数を記録へ残します。
    def notes_for(draft)
      emphasized = draft.main_terms.count { |term| term.include?(EMPHASIS_MARK) }

      [{ kind: EMPHASIS_NOTE_KIND, emphasized: emphasized,
         weight: rules.fetch('emphasis_weight') }]
    end

    # 最上位の指示にだけ重みを付けます。
    def weighted(term)
      return term unless term.include?(EMPHASIS_MARK)

      ensure_weightable!(term)
      "(#{term}:#{rules.fetch('emphasis_weight')})"
    end

    # **重みの区切りが混ざったら、その場で失敗させます。**
    # 退避させて進めると、利用者は意図しない強さの絵を受け取ります。
    #
    # **例外に素材そのものを出しません。** 素材には利用者由来の語が入り得ます。
    def ensure_weightable!(term)
      return unless term.match?(WEIGHT_SEPARATOR)

      raise UnsafeTermError,
            '重みを付ける素材に、重みの区切りとなる文字が含まれます。' # 開発者向け
    end

    def negative_prompt_for(draft)
      joined_negative_terms(draft)
    end

    def parameters_for(draft)
      { ASPECT_RATIO_PARAMETER => input_value(draft, :aspect_ratio) }
    end
  end
end
