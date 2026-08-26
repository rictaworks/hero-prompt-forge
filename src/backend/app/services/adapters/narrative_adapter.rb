# frozen_string_literal: true

module Adapters
  # 自然文で書くモデルに共通の組み立てです（requirements.md 4.1 の 7）。
  #
  # **語をカンマで並べただけの文字列は、自然文ではありません。**
  # 区切りを句点へ替えても、`A calm office.` `35mm lens.` のように述語を持たない
  # 名詞句が並ぶだけです。自然文を求めるモデルが期待しているのは、
  # **要素どうしの関係が伝わる形**です（PR #154 のレビューより）。
  #
  # そこで、**述語のある 2 文**に組み立てます。
  #
  #   This is a hero image for a website, composed for a 16:9 frame.
  #   The image includes a calm office, 35mm lens, and clear copy space ... .
  #
  # **アスペクト比を二度言いません。** 素材が既にアスペクト比を述べている場合、
  # 先頭の文からは外します。
  #
  # **`Kernel.format` を明示して呼びます。** この層の公開メソッドが `format` で、
  # そのままでは自分自身を呼ぶためです。
  class NarrativeAdapter < ModelAdapter
    # 記法が必ず持つ鍵です。
    REQUIRED_KEYS = %w[opening frame body term_separator final_separator
                       pair_separator sentence_separator period].freeze

    class << self
      def required_keys = REQUIRED_KEYS
    end

    private

    def main_prompt_for(draft)
      [opening_sentence(draft), body_sentence(draft)]
        .join(rules.fetch('sentence_separator'))
    end

    def opening_sentence(draft)
      "#{rules.fetch('opening')}#{frame_clause(draft)}#{rules.fetch('period')}"
    end

    # **素材が既にアスペクト比を述べていれば、重ねません。**
    def frame_clause(draft)
      aspect_ratio = input_value(draft, :aspect_ratio)
      return '' if draft.main_terms.any? { |term| term.include?(aspect_ratio) }

      Kernel.format(rules.fetch('frame'), aspect_ratio: aspect_ratio)
    end

    def body_sentence(draft)
      body = Kernel.format(rules.fetch('body'), terms: listed(draft.main_terms))

      "#{body}#{rules.fetch('period')}"
    end

    # 素材を、読める形の並びにします。
    #
    # **2 件のときに `A, and B` と書きません。** 読点が余計です。
    def listed(terms)
      return terms.first if terms.one?
      return terms.join(rules.fetch('pair_separator')) if terms.size == 2

      "#{terms[..-2].join(rules.fetch('term_separator'))}#{rules.fetch('final_separator')}#{terms.last}"
    end
  end
end
