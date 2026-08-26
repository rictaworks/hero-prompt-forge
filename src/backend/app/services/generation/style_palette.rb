# frozen_string_literal: true

module Generation
  # スタイル系統が持つ配色の指定と、ブランドカラーの衝突を解きます
  # （requirements.md 4.1 の 5）。
  #
  # 優先順位は ② ブランドカラー ＞ ③ スタイル系統です。スタイル系統の配色指定
  # （`two brand colors plus one neutral` など）は事実上の支配色の指定であり、
  # 「アクセントとして統合する」という ② の扱いと食い違います。
  #
  # **捨てずに弱めます。** 4.1 の 5 は、下位の指定を「捨てる」のではなく
  # 「弱める」と定めています。
  #
  # **ブランドカラーの指定が無ければ、衝突しません。** そのままにします。
  class StylePalette
    # ノートに残す印です。文言ではなく記号で持ちます。
    NOTE_KIND = :style_palette_weakened

    MATCH_KEY = 'match'
    WEAKENED_KEY = 'weakened'

    def initialize(conflicts)
      @conflicts = conflicts
    end

    # 弱めた素材と、弱めた事実のノートを返します。
    # @return [Hash] `:main_terms` と `:notes` を持ちます
    def weaken(main_terms)
      notes = []
      weakened = main_terms.map do |term|
        conflict = conflict_for(term)
        next term if conflict.nil?

        notes << note_for(term, conflict)
        conflict.fetch(WEAKENED_KEY)
      end

      { main_terms: weakened.uniq, notes: notes }
    end

    private

    attr_reader :conflicts

    def conflict_for(term)
      conflicts.find { |conflict| term.include?(conflict.fetch(MATCH_KEY)) }
    end

    def note_for(term, conflict)
      { kind: NOTE_KIND, term: term,
        matched: conflict.fetch(MATCH_KEY), weakened: conflict.fetch(WEAKENED_KEY) }
    end
  end
end
