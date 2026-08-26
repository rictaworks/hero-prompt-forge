# frozen_string_literal: true

module Generation
  # スタイル仕様化規則の検めです（requirements.md 4.1 の 3、4.2）。
  #
  # **規則辞書は管理画面から人が編集するデータです**（requirements.md 4.3）。
  # 必須の項目が欠けたまま通すと、撮影指示を欠いたプロンプトが出ます。
  # **4.2 は「撮影指示を欠くプロンプトは出力しない」と定めています。**
  # 欠けていることに気づける唯一の場所がここです。
  class StyleRulesTable
    InvalidDictionaryError = StyleRules::InvalidDictionaryError

    REQUIRED_KEY = StyleRules::REQUIRED_KEY
    PERSON_SAFETY_KEY = StyleRules::PERSON_SAFETY_KEY
    PERSON_SAFETY_REQUIRED_STYLES = StyleRules::PERSON_SAFETY_REQUIRED_STYLES

    class << self
      def ensure_rules!(rules, version)
        unless rules.is_a?(Hash) && rules.any?
          raise InvalidDictionaryError,
                "規則辞書のスタイル仕様化規則がありません: #{version}" # 開発者向け
        end

        rules.each { |style_family, rule| ensure_rule!(style_family, rule, version) }
      end

      # 避ける構図も、そのままプロンプトへ入れられる英文でなければなりません。
      def ensure_compositions!(style_family, compositions, version)
        ensure_person_safety_present!(style_family, compositions, version)
        return if compositions.all? { |item| item.is_a?(String) && !item.strip.empty? }

        raise InvalidDictionaryError,
              "避ける構図が文字列ではありません: #{style_family} (#{version})" # 開発者向け
      end

      private

      def ensure_rule!(style_family, rule, version)
        unless rule.is_a?(Hash)
          raise InvalidDictionaryError,
                "スタイル系統の規則が連想配列ではありません: #{style_family} (#{version})" # 開発者向け
        end

        required = rule[REQUIRED_KEY]
        return if required.is_a?(Array) && required.any?

        raise InvalidDictionaryError,
              "必ず出す項目の一覧がありません: #{style_family} (#{version})" # 開発者向け
      end

      # **実写系で避ける構図が消えていたら、その場で失敗させます。**
      # 空の一覧を黙って返すと、顔と手指の破綻を避ける指示が出なくなります。
      def ensure_person_safety_present!(style_family, compositions, version)
        return unless PERSON_SAFETY_REQUIRED_STYLES.include?(style_family)
        return if compositions.any?

        raise InvalidDictionaryError,
              "避ける構図がありません: #{style_family}.#{PERSON_SAFETY_KEY} (#{version})" # 開発者向け
      end
    end
  end
end
