# frozen_string_literal: true

module Adapters
  # 自然文で書くモデルに共通の組み立てです（requirements.md 4.1 の 7）。
  #
  # **語をカンマで並べただけの文字列は、自然文ではありません。**
  # 区切りを句点へ替えても、`A calm office.` `35mm lens.` のように述語を持たない
  # 名詞句が並ぶだけです。自然文を求めるモデルが期待しているのは、
  # **要素どうしの関係が伝わる形**です（PR #154 のレビューより）。
  #
  # そこで、**述語のある文**に組み立てます。
  #
  #   This is a hero image for a website.
  #   The image shows a calm office, 35mm lens, and clear copy space ... .
  #   The whole frame is composed for a 16:9 wide crop.
  #
  # **画面の比は、独立した 1 文で述べます。** 素材の並びへ混ぜると、
  # `The image shows ... composed for a 16:9 wide crop` となり、
  # **`shows` が過去分詞句を受ける形**になって文になりません。
  #
  # **どの素材が画面の比を述べているかは、コピースペースの段のノートから
  # 受け取ります。** 素材の文字列を照合して見分けると、言い回しが変わったときに
  # 黙って外れます（PR #154 の 2 回目のレビューより）。
  #
  # **`Kernel.format` を明示して呼びます。** この層の公開メソッドが `format` で、
  # そのままでは自分自身を呼ぶためです。
  class NarrativeAdapter < ModelAdapter
    # 記法が必ず持つ鍵です。
    REQUIRED_KEYS = %w[opening body frame default_frame_clause term_separator final_separator
                       pair_separator sentence_separator period].freeze

    class << self
      def required_keys = REQUIRED_KEYS
    end

    private

    def main_prompt_for(draft)
      [opening_sentence, body_sentence(draft), frame_sentence(draft)]
        .compact.join(rules.fetch('sentence_separator'))
    end

    def opening_sentence
      sentence(rules.fetch('opening'))
    end

    # **画面の比を述べる素材を、並びから外します。**
    def body_sentence(draft)
      terms = draft.main_terms - [aspect_ratio_term(draft)].compact
      return nil if terms.empty?

      sentence(Kernel.format(rules.fetch('body'), terms: listed(terms)))
    end

    # 画面の比を、独立した 1 文で述べます。
    #
    # **素材が比を述べていれば、その言い回しをそのまま使います。**
    # 二度言わず、かつ設定の言い回しが使われないまま残ることもありません。
    def frame_sentence(draft)
      clause = aspect_ratio_term(draft) ||
               Kernel.format(rules.fetch('default_frame_clause'),
                             aspect_ratio: input_value(draft, :aspect_ratio))

      sentence(Kernel.format(rules.fetch('frame'), clause: clause))
    end

    # コピースペースの段が残した、画面の比を述べる素材です。
    def aspect_ratio_term(draft)
      note = draft.notes.find { |item| item[:kind] == Generation::CopySpace::NOTE_KIND }
      term = note ? note[:aspect_ratio_term] : nil
      return term if term.is_a?(String) && draft.main_terms.include?(term)

      nil
    end

    def sentence(text)
      "#{text}#{rules.fetch('period')}"
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
