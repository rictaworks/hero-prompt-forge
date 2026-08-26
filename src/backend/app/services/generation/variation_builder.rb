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
      dropped = dropped_terms(draft, applied, chosen)
      swapped = swapped_terms(draft, applied, chosen, dropped)

      traced(swapped, dropped) { assembled(draft, chosen, dropped, swapped) }
    end

    private

    attr_reader :rules, :composition, :name, :index

    def traced(swapped, dropped, &)
      Trace.step('generation.variation_expanded',
                 composition: name, number: index + 1,
                 swapped: swapped[:swapped], dropped: dropped.size, &)
    end

    def assembled(draft, chosen, dropped, swapped)
      draft.replace(
        main_terms: swapped[:main_terms],
        notes: rewritten_notes(draft, chosen, dropped)
      ).add(
        main_terms: [composition.fetch(VariationRules::FOCUS_KEY)],
        notes: [variation_note] + dropped_notes(dropped)
      )
    end

    def variation_note
      { kind: VariationExpander::NOTE_KIND, composition: name, number: index + 1 }
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
    def dropped_terms(draft, applied, chosen)
      composition.fetch(VariationRules::DROPS_KEY)
                 .index_with { |role| term_for_role(draft, applied, role, chosen) }
                 .compact
    end

    # 役割の名前から、その素材を引きます。
    #
    # **素材の文字列を照合して見分けません。** 言い回しが変わると黙って外れます。
    def term_for_role(draft, applied, role, chosen)
      return person_safety_terms(draft).first if role == PERSON_SAFETY_ROLE

      roles = copy_space_roles(draft)
      return roles[role] if roles.key?(role)

      position = rules.required_items_for(applied[:style_family]).index(role)
      position ? chosen[position] : nil
    end

    def copy_space_roles(draft)
      note = draft.notes.find { |item| item[:kind] == CopySpace::NOTE_KIND }
      note && note[:roles].is_a?(Hash) ? note[:roles] : {}
    end

    # 案ごとに、一覧で選べる値を選び直し、外す素材を落とします。
    def swapped_terms(draft, applied, chosen, dropped)
      replacements = applied[:specifications].zip(chosen).to_h
                                             .merge(person_safety_replacements(draft, dropped))
      kept = draft.main_terms - dropped.values.compact

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

    # **控えを、実際の素材に合わせます。**
    def rewritten_notes(draft, chosen, dropped)
      removed = dropped.values.compact

      draft.notes.filter_map { |note| rewritten_note(note, chosen - removed, dropped) }
    end

    def rewritten_note(note, specifications, dropped)
      return note.merge(specifications: specifications) if note[:kind] == StyleSpec::SPECIFICATIONS_NOTE_KIND
      return nil if note[:kind] == StyleSpec::PERSON_SAFETY_NOTE_KIND && dropped.key?(PERSON_SAFETY_ROLE)

      note
    end

    def style_family_of(draft)
      specifications_note_of(draft)[:style_family]
    end

    def specifications_note_of(draft)
      draft.notes.find { |item| item[:kind] == StyleSpec::SPECIFICATIONS_NOTE_KIND }
    end
  end
end
