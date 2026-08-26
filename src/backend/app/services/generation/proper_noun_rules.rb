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

    # 会社名のうしろに付く語として認める形です。
    # **記号や空白を含む語を認めません。** 落とす判定が静かに壊れます。
    ATTRIBUTE_WORD_FORMAT = /\A[ぁ-ゖァ-ヴー一-龥]{1,10}\z/
    ATTRIBUTE_WORDS_KEY = 'company_attribute_words'
    ATTRIBUTE_PARTICLE_KEY = 'company_attribute_particle'

    class << self
      # @return [Array<Hash>]
      def load_rules(path)
        rules = read(path)[RULES_KEY]
        unless rules.is_a?(Array) && rules.any?
          raise InvalidDefinitionError, "手がかりがありません: #{path}" # 開発者向け
        end

        rules.map { |rule| build_rule(rule) }
      end

      # 会社名のうしろに付きやすい、会社そのものを指さない語です（issue #153）。
      #
      # **拾った名前の末尾が「の＋この一覧の語」で終わる場合だけ、そこを落とします。**
      # 一覧に無ければ、拾った名前をそのまま使います。
      #
      # **語そのものの形も検めます。** 空の語や記号を含む語が混ざると、
      # 落とす判定が静かに壊れます（PR #157 のレビューより）。
      # @return [Array<String>]
      def load_attribute_words(path)
        loaded = read(path)
        words = loaded[ATTRIBUTE_WORDS_KEY]
        ensure_attribute_words!(words, path)
        particle = loaded[ATTRIBUTE_PARTICLE_KEY]
        ensure_particle!(particle, path)

        { ATTRIBUTE_PARTICLE_KEY => particle, ATTRIBUTE_WORDS_KEY => words }.freeze
      end

      # **名前と語をつなぐ助詞です。** 1 文字のかなだけを認めます。
      def ensure_particle!(particle, path)
        return if particle.is_a?(String) && particle.match?(/\A[ぁ-ゖ]\z/)

        raise InvalidDefinitionError,
              "名前と語をつなぐ助詞が読めません: #{path}" # 開発者向け
      end

      def ensure_attribute_words!(words, path)
        return if words.is_a?(Array) && words.any? &&
                  words.all? { |word| word.is_a?(String) && word.match?(ATTRIBUTE_WORD_FORMAT) }

        raise InvalidDefinitionError,
              "会社名のうしろに付く語の一覧が読めません: #{path}" # 開発者向け
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
