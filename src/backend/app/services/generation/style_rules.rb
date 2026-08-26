# frozen_string_literal: true

module Generation
  # スタイル系統ごとの仕様化規則です（requirements.md 4.1 の 3、4.2）。
  #
  # 規則辞書の `style_spec_rules` を読み、**中身を検めます。** 規則辞書は管理画面から
  # 人が編集するデータです（requirements.md 4.3）。必須の項目が欠けたまま通すと、
  # 撮影指示を欠いたプロンプトが出ます。**4.2 は「撮影指示を欠くプロンプトは
  # 出力しない」と定めています。** 欠けていることに気づける唯一の場所がここです。
  #
  # 各スタイルの規則は次の形です。
  #
  #   required       : 必ず出す項目の一覧です。この一覧の項目がすべて要ります
  #   <項目名>        : その項目の指示です。文字列、または選べる値の一覧です
  #   person_safety  : 人物を含む場合に、顔や手指の破綻を避ける構図です
  #
  # **値は、そのままプロンプトへ入れられる英文でなければなりません。**
  # 記号や数値を書くと、生成モデルへ「back_view」「24」といった意味をなさない語が
  # そのまま渡ります。文字列でない値は、その場で失敗させます。
  #
  # **選べる値が一覧で書かれている場合は、先頭を既定として使います。**
  # 並び順が既定の優先順です。3 案への展開（issue #50）で別の値を使う場合は、
  # そちらが選び直します。
  class StyleRules
    # 規則辞書の内容が足りない、または壊れている場合に投げます。
    class InvalidDictionaryError < StandardError; end

    # 定義されていないスタイル系統を渡された場合に投げます。
    class UnknownStyleError < StandardError; end

    # スタイル仕様化規則の鍵です。
    STYLE_SPEC_RULES_KEY = 'style_spec_rules'
    # 必ず出す項目の一覧の鍵です。
    REQUIRED_KEY = 'required'
    # 人物を含む場合に避ける構図の鍵です。
    PERSON_SAFETY_KEY = 'person_safety'

    # 項目の値そのものではなく、入れ子の中に指示を持つ項目の鍵です。
    NESTED_KEYS = %w[lighting].freeze

    def initialize(dictionary)
      @version = dictionary.version
      @rules = dictionary.style_spec_rules
      ensure_rules!
    end

    # そのスタイル系統で、必ず出す指示の一覧を返します。
    # @return [Array<String>]
    def specifications_for(style_family)
      rule = rule_for(style_family)

      rule.fetch(REQUIRED_KEY).map { |item| specification(rule, style_family, item) }
    end

    # 人物を含む場合に、顔や手指の破綻を避ける構図です。
    # **複製して返します。** そのまま返すと、呼び出す側から規則の中身を書き換えられます。
    def person_safety_for(style_family)
      compositions = Array(rule_for(style_family)[PERSON_SAFETY_KEY])
      ensure_compositions!(style_family, compositions)

      compositions.dup
    end

    # 定義されているスタイル系統です。
    def style_families
      @rules.keys
    end

    private

    # 避ける構図も、そのままプロンプトへ入れられる英文でなければなりません。
    def ensure_compositions!(style_family, compositions)
      return if compositions.all? { |item| item.is_a?(String) && !item.strip.empty? }

      raise InvalidDictionaryError,
            "避ける構図が文字列ではありません: #{style_family} (#{@version})" # 開発者向け
    end

    def rule_for(style_family)
      @rules.fetch(style_family) do
        raise UnknownStyleError,
              "定義されていないスタイル系統です: #{style_family.inspect}" # 開発者向け
      end
    end

    # 1 つの項目の指示を取り出します。
    #
    # 一覧で書かれている場合は先頭を使います。入れ子（照明のように複数の指示を
    # まとめたもの）の場合は、その中から取り出します。
    def specification(rule, style_family, item)
      value = rule[item] || nested_value(rule, item)
      ensure_specification!(style_family, item, value)

      value.is_a?(Array) ? value.first : value
    end

    def nested_value(rule, item)
      NESTED_KEYS.filter_map { |key| rule[key].is_a?(Hash) ? rule[key][item] : nil }.first
    end

    # **必須の項目が欠けていたら、その場で失敗させます。**
    # 欠けたまま通すと、撮影指示を欠いたプロンプトが出ます。
    #
    # **文字列でない値も失敗させます。** 数値や記号を黙って文字列へ直すと、
    # 「24」「back_view」といった意味をなさない語がプロンプトへ入ります。
    def ensure_specification!(style_family, item, value)
      if value.nil?
        raise InvalidDictionaryError,
              "必須の項目がありません: #{style_family}.#{item} (#{@version})" # 開発者向け
      end

      chosen = value.is_a?(Array) ? value.first : value
      ensure_prompt_text!(style_family, item, value, chosen)
    end

    def ensure_prompt_text!(style_family, item, value, chosen)
      reason = prompt_text_problem(value, chosen)
      return if reason.nil?

      raise InvalidDictionaryError,
            "必須の項目が#{reason}: #{style_family}.#{item} (#{@version})" # 開発者向け
    end

    def prompt_text_problem(value, chosen)
      return '一覧として空です' if value.is_a?(Array) && value.empty? # 開発者向け
      return "文字列ではありません（#{chosen.class}）" unless chosen.is_a?(String) # 開発者向け
      return '空です' if chosen.strip.empty? # 開発者向け

      nil
    end

    def ensure_rules!
      unless @rules.is_a?(Hash) && @rules.any?
        raise InvalidDictionaryError,
              "規則辞書のスタイル仕様化規則がありません: #{@version}" # 開発者向け
      end

      @rules.each { |style_family, rule| ensure_rule!(style_family, rule) }
    end

    def ensure_rule!(style_family, rule)
      unless rule.is_a?(Hash)
        raise InvalidDictionaryError,
              "スタイル系統の規則が連想配列ではありません: #{style_family} (#{@version})" # 開発者向け
      end

      required = rule[REQUIRED_KEY]
      return if required.is_a?(Array) && required.any?

      raise InvalidDictionaryError,
            "必ず出す項目の一覧がありません: #{style_family} (#{@version})" # 開発者向け
    end
  end
end
