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
  #
  # ## 役割ごとの述語（issue #156）
  #
  # **撮影の手段を、画に写っているものとして述べません。** レンズは撮影の手段で
  # あり、画に写るものではありません。`The image shows ..., a 35mm lens, ...` は
  # **「35mm レンズが写った絵」を呼び込みかねません。**
  #
  # **素材の役割は、控えから受け取ります**（`TermRoles`）。素材の文字列を照合
  # して見分けると、言い回しが変わったときに黙って外れます。
  #
  # **控えに役割が無い素材も、文として成立する形で述べます。** 既定の文
  # （`body`）へ入れます。
  #
  #   This is a hero image for a website.
  #   The image shows a calm dental clinic.
  #   The scene is photographed with a 35mm lens, and shallow depth of field ... .
  #   The composition keeps the main subject placed at ..., and clear copy space ... .
  #   The whole frame is composed for a 16:9 wide crop.
  class NarrativeAdapter < ModelAdapter
    # 記法が必ず持つ鍵です。
    REQUIRED_KEYS = %w[opening body frame default_frame_clause term_separator final_separator
                       pair_separator sentence_separator period].freeze

    # 役割ごとの述語の鍵です。**文字列ではありませんので、別に検めます。**
    ROLE_CLAUSES_KEY = 'role_clauses'
    CLAUSE_ROLES_KEY = 'roles'
    CLAUSE_TEMPLATE_KEY = 'template'

    class << self
      def required_keys = REQUIRED_KEYS
    end

    private

    def main_prompt_for(draft)
      ([opening_sentence] + grouped_sentences(draft) + [frame_sentence(draft)])
        .compact.join(rules.fetch('sentence_separator'))
    end

    def opening_sentence
      sentence(rules.fetch('opening'))
    end

    # 役割ごとに文を組み立てます。
    #
    # **上から順に見て、はじめに当たった役割の文へ入れます。**
    # **どの役割にも当たらない素材は、既定の文で述べます。**
    def grouped_sentences(draft)
      grouped = grouped_terms(draft)

      [body_sentence(grouped.fetch(:rest))] + grouped.fetch(:clauses).map do |clause, terms|
        sentence(Kernel.format(clause.fetch(CLAUSE_TEMPLATE_KEY), terms: listed(terms)))
      end
    end

    # 素材を、役割ごとの組へ分けます。
    #
    # **上から順に見て、はじめに当たった役割の組へ入れます。**
    # **どの役割にも当たらない素材は `:rest` です。**
    def grouped_terms(draft)
      roles = TermRoles.of(draft)
      remaining = draft.main_terms - [aspect_ratio_term(draft)].compact
      taken = []

      clauses = role_clauses.filter_map do |clause|
        terms = remaining.select { |term| clause.fetch(CLAUSE_ROLES_KEY).include?(roles[term]) }
        taken.concat(terms)
        terms.empty? ? nil : [clause, terms]
      end

      { clauses: clauses, rest: remaining - taken }
    end

    # 役割ごとの述語の定義です。**中身を検めます。**
    def role_clauses
      @role_clauses ||= ensure_clauses!(rules[ROLE_CLAUSES_KEY])
    end

    # **人が編集するデータですので、中身を信用しません。**
    def ensure_clauses!(clauses)
      unless clauses.is_a?(Array) && clauses.all? { |clause| clause_valid?(clause) }
        raise InvalidDefinitionError,
              "役割ごとの述語の形が違います: #{self.class.model_key}" # 開発者向け
      end

      clauses
    end

    def clause_valid?(clause)
      return false unless clause.is_a?(Hash)

      roles = clause[CLAUSE_ROLES_KEY]
      template = clause[CLAUSE_TEMPLATE_KEY]

      roles.is_a?(Array) && roles.all?(String) && roles.any? &&
        template.is_a?(String) && template.include?('%<terms>s')
    end

    # **役割の無い素材を述べます。** 1 件も無ければ、この文を出しません。
    def body_sentence(terms)
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
