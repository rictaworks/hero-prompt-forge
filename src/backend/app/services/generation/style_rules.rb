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

    # 避ける構図を必ず持つスタイル系統です。
    #
    # requirements.md 4.2 は「撮影指示を欠くプロンプトは出力しない」と
    # 「人物の顔を正面から大きく描写する構図は既定で回避する」を**同格で**
    # 定めています。前者だけを必須にすると、規則辞書の編集で `person_safety` を
    # 消したときに、顔の回避が黙って効かなくなります。
    #
    # 実写系だけを対象にします。顔と手指の破綻は、写真として見える出力で
    # 最も表に出るためです。
    PERSON_SAFETY_REQUIRED_STYLES = %w[photoreal].freeze

    # 項目の値そのものではなく、入れ子の中に指示を持つ項目の鍵です。
    NESTED_KEYS = %w[lighting].freeze

    def initialize(dictionary)
      @version = dictionary.version
      @rules = dictionary.style_spec_rules
      ensure_rules!
    end

    # そのスタイル系統で、必ず出す指示の一覧を返します。
    #
    # @param variation [Integer] 何案目かです。**一覧で書かれた項目の選び直しに使います**
    # @return [Array<String>]
    def specifications_for(style_family, variation: 0)
      rule = rule_for(style_family)

      rule.fetch(REQUIRED_KEY).map { |item| specification(rule, style_family, item, variation) }
    end

    # 人物を含む場合に、顔や手指の破綻を避ける構図です。
    # **複製して返します。** そのまま返すと、呼び出す側から規則の中身を書き換えられます。
    def person_safety_for(style_family)
      compositions = Array(rule_for(style_family)[PERSON_SAFETY_KEY])
      ensure_compositions!(style_family, compositions)

      compositions.dup
    end

    # 指定した項目が取り得る値をすべて返します。
    #
    # **矛盾解決（issue #43）が、配色指定そのものを見分けるために使います。**
    # 語の一部が含まれるかどうかで当てると、利用者由来の素材まで置き換えます。
    #
    # **定義されていない項目は、値を持たないものとして扱います。**
    # スタイル系統によって持つ項目が違うためです。
    # @return [Array<String>]
    def values_for(style_family, items)
      rule = rule_for(style_family)

      items.flat_map { |item| Array(rule[item]) }
    end

    # そのスタイル系統で、必ず出す項目の名前です。
    #
    # **バリエーションの展開（issue #50）が、外す素材を役割の名前で引くために
    # 使います。** 素材の文字列を照合して見分けると、言い回しが変わったときに
    # 黙って外れます。
    # @return [Array<String>]
    def required_items_for(style_family)
      rule_for(style_family).fetch(REQUIRED_KEY).dup
    end

    # 定義されているスタイル系統です。
    def style_families
      @rules.keys
    end

    # 読み込んだ規則辞書の版です。適用した版を記録へ残すために使います。
    attr_reader :version

    private

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
    def specification(rule, style_family, item, variation)
      value = rule[item] || nested_value(rule, item)
      ensure_specification!(style_family, item, value)

      chosen(value, variation)
    end

    # **一覧を一巡したら先頭へ戻ります。** 案の数と選べる値の数は一致しません。
    def chosen(value, variation)
      return value unless value.is_a?(Array)

      value[variation % value.size]
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
      StyleRulesTable.ensure_rules!(@rules, @version)
    end

    def ensure_compositions!(style_family, compositions)
      StyleRulesTable.ensure_compositions!(style_family, compositions, @version)
    end
  end
end
