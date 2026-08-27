# frozen_string_literal: true

module Generation
  # バリエーション 1 案の控えの書き直しです（requirements.md 4.1 の 8）。
  #
  # **控えを、実際の素材に合わせます。** 選び直したのに控えが古いままだと、
  # アートディレクションノート（issue #51）が利用者へ誤った説明を出します
  # （PR #155 のレビューより）。
  #
  # **外した素材は、選び直したあとの値でも控えから外します。**
  # 一覧で選べる項目を外す場合、当てた値と選び直した値が違いますので、
  # 位置で対応づけて外します。
  class VariationNotes
    # @param applied [Hash] スタイル仕様化が残した控えです
    # @param chosen [Array<String>] その案で選び直した指示です
    # @param dropped [Hash] 役割の名前から、外した素材への対応です
    # @param person_safety [Array<String>] その案で当てる、人物を避ける構図です
    def initialize(applied:, chosen:, dropped:, person_safety: [])
      @applied = applied
      @chosen = chosen
      @dropped = dropped
      @person_safety = person_safety
    end

    # 書き直した控えを返します。
    # @return [Array<Hash>]
    def rewrite(notes)
      notes.filter_map { |note| rewritten(note) }
    end

    private

    attr_reader :applied, :chosen, :dropped, :person_safety

    def rewritten(note)
      return rewritten_specifications(note) if specifications_note?(note)
      return nil if dropped_person_safety_note?(note)
      return rewritten_person_safety(note) if person_safety_note?(note)

      note
    end

    def rewritten_specifications(note)
      note.merge(specifications: kept_specifications, roles: kept_roles)
    end

    def rewritten_person_safety(note)
      note.merge(compositions: person_safety, roles: person_safety_roles)
    end

    # **役割と素材の対応も、選び直したあとの値へそろえます**（issue #156）。
    #
    # そろえないと、整形の段が古い素材で役割を引き、**選び直した素材が
    # 役割を失って既定の述語で述べられます。**
    def kept_roles
      names = Array(applied[:roles]).map(&:first)

      names.zip(chosen).to_h
           .reject { |name, _term| dropped.value?(applied[:roles][name]) }
    end

    def person_safety_roles
      return {} if person_safety.empty?

      { VariationBuilder::PERSON_SAFETY_ROLE => person_safety.first }
    end

    def person_safety_note?(note)
      note[:kind] == StyleSpec::PERSON_SAFETY_NOTE_KIND
    end

    def specifications_note?(note)
      note[:kind] == StyleSpec::SPECIFICATIONS_NOTE_KIND
    end

    def dropped_person_safety_note?(note)
      note[:kind] == StyleSpec::PERSON_SAFETY_NOTE_KIND &&
        dropped.key?(VariationBuilder::PERSON_SAFETY_ROLE)
    end

    def kept_specifications
      chosen.each_with_index
            .reject { |_value, position| dropped.value?(applied[:specifications][position]) }
            .map(&:first)
    end
  end
end
