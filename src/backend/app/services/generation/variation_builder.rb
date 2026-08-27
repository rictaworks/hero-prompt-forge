# frozen_string_literal: true

module Generation
  # バリエーション 1 案の組み立てです（requirements.md 4.1 の 8）。
  #
  # **主役の置き方だけを変えるのではありません。** 一覧で選べる指示は案ごとに
  # 選び直し、その案で意味を持たない指示は外します。
  #
  # **控えを、実際の素材に合わせます。** 選び直したのに控えが古いままだと、
  # アートディレクションノート（issue #51）が利用者へ誤った説明を出します
  # （PR #155 のレビューより）。
  class VariationBuilder
    # 人物を避ける構図を指す役割の名前です。
    PERSON_SAFETY_ROLE = 'person_safety'

    # @param rules [StyleRules] スタイル仕様化規則です
    # @param composition [Hash] その案の構図の定義です
    # @param index [Integer] 何案目かです（0 から数えます）
    def initialize(rules:, composition:, name:, index:)
      @rules = rules
      @composition = composition
      @name = name
      @index = index
    end

    # 1 案ぶんの下書きを返します。
    # @return [Draft]
    def build(draft)
      applied = specifications_note_of(draft)
      chosen = specifications_for(applied)
      dropped = dropped_terms(draft, applied)
      swapped = swapped_terms(draft, applied, chosen, dropped)

      traced(swapped, dropped) { assembled(draft, applied, chosen, dropped, swapped) }
    end

    private

    attr_reader :rules, :composition, :name, :index

    def traced(swapped, dropped, &)
      Trace.step('generation.variation_expanded',
                 composition: name, number: index + 1,
                 swapped: swapped[:swapped], dropped: dropped.size, &)
    end

    def assembled(draft, applied, chosen, dropped, swapped)
      draft.replace(
        main_terms: swapped[:main_terms],
        notes: rewritten_notes(draft, applied, chosen, dropped)
      ).add(
        main_terms: [composition.fetch(VariationRules::FOCUS_KEY)],
        notes: [variation_note] + dropped_notes(dropped)
      )
    end

    # **役割の名前も一緒に残します**（issue #156）。
    def variation_note
      { kind: VariationExpander::NOTE_KIND, composition: name, number: index + 1,
        roles: { VariationExpander::FOCUS_ROLE => composition.fetch(VariationRules::FOCUS_KEY) } }
    end

    # **外した事実を、役割ごとに残します。**
    def dropped_notes(dropped)
      dropped.map do |role, term|
        { kind: VariationExpander::DROPPED_NOTE_KIND, role: role, term: term }
      end
    end

    # 案ごとの、スタイル仕様化の指示です。
    #
    # **控えの件数と一致することを求めます。** 一致しないまま組むと、
    # 足りない分が `nil` になり、素材が記録も残さずに落ちます。
    def specifications_for(applied)
      chosen = rules.specifications_for(applied[:style_family], variation: index)
      return chosen if chosen.size == applied[:specifications].size

      raise VariationExpander::VersionMismatchError,
            "仕様化の指示の数が控えと違います: #{chosen.size} != #{applied[:specifications].size}" # 開発者向け
    end

    # その案で外す素材を、役割ごとに集めます。
    #
    # **その下書きに無い役割は、外すものがありません。** 人物が写らない見込みの
    # 業種には人物の構図が入りませんし、被写界深度を持たないスタイル系統も
    # あります。**役割の名前そのものは、組み立ての時点で検めています。**
    def dropped_terms(draft, applied)
      composition.fetch(VariationRules::DROPS_KEY)
                 .index_with { |role| term_for_role(draft, applied, role) }
                 .compact
    end

    # 役割の名前から、**いま下書きに入っている素材**を引きます。
    #
    # **素材の文字列を照合して見分けません。** 言い回しが変わると黙って外れます。
    #
    # **選び直したあとの値ではなく、当てられている値を引きます。**
    # 選び直したあとの値で引くと、下書きの素材と一致せず、引き算が当たりません。
    # 差し替えの対象になっている素材を外す場合に、そのまま復活します
    # （PR #155 の 2 回目のレビューより）。
    def term_for_role(draft, applied, role)
      term = lookup_role(draft, applied, role)
      return term if term.is_a?(String) && draft.main_terms.include?(term)

      nil
    end

    def lookup_role(draft, applied, role)
      return person_safety_terms(draft).first if role == PERSON_SAFETY_ROLE

      roles = copy_space_roles(draft)
      return roles[role] if roles.key?(role)

      position = rules.required_items_for(applied[:style_family]).index(role)
      position ? applied[:specifications][position] : nil
    end

    def copy_space_roles(draft)
      note = draft.notes.find { |item| item[:kind] == CopySpace::NOTE_KIND }
      note && note[:roles].is_a?(Hash) ? note[:roles] : {}
    end

    # 案ごとに、一覧で選べる値を選び直し、外す素材を落とします。
    def swapped_terms(draft, applied, chosen, dropped)
      replacements = applied[:specifications].zip(chosen).to_h
                                             .merge(person_safety_replacements(draft, dropped))
      kept = draft.main_terms - dropped.values

      { main_terms: kept.map { |term| replacements.fetch(term, term) },
        swapped: swapped_count(kept, replacements) }
    end

    # 差し替えた件数です。**記録に残します。**
    def swapped_count(terms, replacements)
      terms.count { |term| replacements.key?(term) && replacements[term] != term }
    end

    # 人物を避ける構図を、案ごとの構図へ差し替えます。
    #
    # **外す案では差し替えません。** 落とす側で扱います。
    def person_safety_replacements(draft, dropped)
      applied = person_safety_terms(draft)
      return {} if applied.empty? || dropped.key?(PERSON_SAFETY_ROLE)

      choices = rules.person_safety_for(style_family_of(draft))
      applied.each_with_index.to_h { |term, offset| [term, choices[(index + offset) % choices.size]] }
    end

    def person_safety_terms(draft)
      note = draft.notes.find { |item| item[:kind] == StyleSpec::PERSON_SAFETY_NOTE_KIND }
      note ? Array(note[:compositions]) : []
    end

    # **控えを、実際の素材に合わせます。** 書き直しは VariationNotes が持ちます。
    def rewritten_notes(draft, applied, chosen, dropped)
      VariationNotes.new(applied: applied, chosen: chosen, dropped: dropped,
                         person_safety: chosen_person_safety(draft, dropped))
                    .rewrite(draft.notes)
    end

    # その案で当てる、人物を避ける構図です。**控えへ書き戻します。**
    def chosen_person_safety(draft, dropped)
      person_safety_replacements(draft, dropped).values
    end

    def style_family_of(draft)
      specifications_note_of(draft)[:style_family]
    end

    def specifications_note_of(draft)
      draft.notes.find { |item| item[:kind] == StyleSpec::SPECIFICATIONS_NOTE_KIND }
    end
  end
end
