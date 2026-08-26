# frozen_string_literal: true

module Generation
  # 固有名詞を見つける手がかりの読み込みと検めです。
  #
  # **手がかりは人が編集するデータです。中身を信用しません。**
  # 意味説明が英文でないまま通すと、生成モデルへ日本語がそのまま渡ります。
  class ProperNounRules
    InvalidDefinitionError = ProperNoun::InvalidDefinitionError

    RULES_KEY = 'rules'
    SUFFIX_READINGS_KEY = 'shop_suffix_readings'

    class << self
      # @return [Array<Hash>]
      def load_rules(path)
        rules = read(path)[RULES_KEY]
        unless rules.is_a?(Array) && rules.any?
          raise InvalidDefinitionError, "手がかりがありません: #{path}" # 開発者向け
        end

        rules.map { |rule| build_rule(rule) }
      end

      # @return [Hash]
      def load_suffix_readings(path)
        readings = read(path)[SUFFIX_READINGS_KEY]
        ensure_readings!(readings, path)

        DeepFreeze.call(readings)
      end

      private

      def read(path)
        loaded = YAML.safe_load_file(Rails.root.join(path))
        return loaded if loaded.is_a?(Hash)

        raise InvalidDefinitionError, "定義が読めません: #{path}" # 開発者向け
      rescue Errno::ENOENT, Psych::SyntaxError => e
        raise InvalidDefinitionError, "定義を読み込めません: #{path} (#{e.class})" # 開発者向け
      end

      def build_rule(rule)
        patterns = fetch_required(rule, 'patterns')
        raise InvalidDefinitionError, "見つける語が空です: #{rule.inspect}" if patterns.empty? # 開発者向け

        {
          kind: fetch_required(rule, 'kind').to_sym,
          gloss: ensure_gloss(fetch_required(rule, 'gloss')),
          matchers: patterns.map { |pattern| Regexp.new(pattern) }
        }
      end

      # **意味説明は、そのままプロンプトへ入る英文です。**
      def ensure_gloss(gloss)
        return gloss if gloss.is_a?(String) && gloss.match?(/\A[a-z][a-z ]+\z/)

        raise InvalidDefinitionError,
              "意味説明が英文ではありません: #{gloss.inspect}" # 開発者向け
      end

      # **語尾の読みは、かなでなければなりません。** ローマ字へ直せません。
      def ensure_readings!(readings, path)
        return if readings.is_a?(Hash) && readings.any? &&
                  readings.values.all? { |value| Romaji.kana?(value.to_s) }

        raise InvalidDefinitionError,
              "屋号の語尾の読みが読めません: #{path}" # 開発者向け
      end

      def fetch_required(rule, key)
        rule.fetch(key) do
          raise InvalidDefinitionError, "#{key} がありません: #{rule.inspect}" # 開発者向け
        end
      end
    end
  end
end
