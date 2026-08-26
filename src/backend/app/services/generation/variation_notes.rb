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
    def initialize(applied:, chosen:, dropped:)
      @applied = applied
      @chosen = chosen
      @dropped = dropped
    end

    # 書き直した控えを返します。
    # @return [Array<Hash>]
    def rewrite(notes)
      notes.filter_map { |note| rewritten(note) }
    end

    private

    attr_reader :applied, :chosen, :dropped

    def rewritten(note)
      return note.merge(specifications: kept_specifications) if specifications_note?(note)
      return nil if dropped_person_safety_note?(note)

      note
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
