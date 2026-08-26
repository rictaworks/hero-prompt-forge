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
  #
  # **当てるのは、スタイル仕様化規則が持つ配色指定そのものです。**
  # 語の一部が含まれるかどうかで当てると、利用者由来の素材まで丸ごと
  # 置き換えます。`a signboard showing the brand colors of the shop` が
  # `a restrained palette led by the brand accent` に化けました
  # （PR #151 の 2 回目のレビューで実測されました）。
  #
  # **この issue は「利用者の指定が黙って消えること」を直すためのものです。**
  # その対策が同じ性質を持っていては、意味がありません。
  class StylePalette
    # ノートに残す印です。文言ではなく記号で持ちます。
    NOTE_KIND = :style_palette_weakened

    ITEMS_KEY = 'items'
    WEAKENED_KEY = 'weakened'

    # 統合の規則とスタイル仕様化規則から組み立てます。
    #
    # @param definition [Hash] 統合の規則です
    # @param style_rules [StyleRules] スタイル仕様化規則です
    # @param style_family [String] そのプロンプトのスタイル系統です
    # @return [StylePalette]
    def self.for(definition:, style_rules:, style_family:)
      conflict = definition.fetch(IntegrationRules::STYLE_PALETTE_CONFLICT_KEY)

      new(values: style_rules.values_for(style_family, conflict.fetch(ITEMS_KEY)),
          weakened: conflict.fetch(WEAKENED_KEY))
    end

    # @param values [Array<String>] スタイル仕様化規則が持つ配色指定の値です
    # @param weakened [String] 弱めた形の英文です
    def initialize(values:, weakened:)
      @values = values
      @weakened = weakened
    end

    # 弱めた素材と、弱めた事実のノートを返します。
    # @return [Hash] `:main_terms` と `:notes` を持ちます
    def weaken(main_terms)
      notes = []
      replaced = false

      terms = main_terms.filter_map do |term|
        next term unless values.include?(term)

        notes << note_for(term)
        next nil if replaced

        replaced = true
        weakened
      end

      { main_terms: terms, notes: notes }
    end

    private

    attr_reader :values, :weakened

    # **重ならないようにするのは、弱めた形だけです。**
    # 素材の全体へ `uniq` を掛けると、もともと重なっていた素材まで
    # 黙って 1 件へまとまり、通る道によって素材の数が変わります。
    def note_for(term)
      { kind: NOTE_KIND, term: term, weakened: weakened }
    end
  end
end
