# frozen_string_literal: true

module Generation
  # ブランドカラーの統合です（requirements.md 4.1 の 5）。
  #
  # **画面全体の支配色にしません。アクセントとして統合します。**
  # 支配色にすると、業種の雰囲気も撮影の指示も、その色に塗りつぶされます。
  #
  # **1 色目をアクセント、2 色目をそれを支える細部として扱います。**
  # 2 色を同じ強さで指定すると、どちらが主なのか決まりません。
  #
  # **アンチAIルック規則に当たる場合は、落とさずに弱めます。**
  # 4.1 の 5 は、下位の指定を「捨てる」のではなく「弱める」と定めています。
  #
  # **色コードではなく色の名前で渡します。** 生成モデルは `#0E7C7B` を色として
  # 受け取りません。名前は ColorName が求めます。
  class BrandColorIntegration
    # 統合の強さです。
    ACCENT = :accent
    SECONDARY_ACCENT = :secondary_accent
    WEAKENED = :weakened

    # ブランドカラーの統合の規則の鍵です。
    BRAND_COLOR_KEY = 'brand_color'

    # @param rules [AntiAiRules] 当たり判定を行います
    # @param definition [Hash] 統合の規則です
    def initialize(rules:, definition:)
      @rules = rules
      @definition = definition
    end

    # 色ごとの統合の内容を、強さの順に返します。
    # @return [Array<Hash>]
    def integrations_for(colors)
      colors.each_with_index.map do |color, index|
        build(color, index.zero? ? ACCENT : SECONDARY_ACCENT)
      end
    end

    private

    attr_reader :rules, :definition

    def build(color, strength)
      name = ColorName.of(color)
      term = text_for(strength, name)
      matched = rules.forbidden_match(term)
      return { color: color, name: name, strength: strength, term: term, matched: nil } if matched.nil?

      { color: color, name: name, strength: WEAKENED, matched: matched,
        term: text_for(WEAKENED, name) }
    end

    # **`Kernel.format` を明示して呼びます。** 差し込めない書き方は、
    # 読み込み時に落としてあります。
    def text_for(strength, name)
      Kernel.format(definition.fetch(BRAND_COLOR_KEY).fetch(strength.to_s), color: name)
    end
  end
end
