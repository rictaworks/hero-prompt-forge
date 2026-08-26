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
    NAME_WORDS_KEY = 'name_forming_words'

    # 手がかりの中で、名前に使われる語の一覧へ差し替える場所です。
    #
    # **同じ一覧を手がかりごとに書き写しません。** 会社の種別は 4 通りあり、
    # 書き写すと、一覧を直すときに 4 か所すべてを直すことになります。
    NAME_WORDS_PLACEHOLDER = '%<name_words>s'

    class << self
      # @return [Array<Hash>]
      def load_rules(path)
        loaded = read(path)
        rules = loaded[RULES_KEY]
        unless rules.is_a?(Array) && rules.any?
          raise InvalidDefinitionError, "手がかりがありません: #{path}" # 開発者向け
        end

        name_words = name_words_of(loaded, path)

        rules.map { |rule| build_rule(rule, name_words) }
      end

      # 名前に使われる語の一覧です。
      #
      # **「の」が名前の一部か、文をつなぐ助詞かは、文字だけでは決まりません。**
      # 「株式会社みらいの強み」の「の」は助詞ですが、「株式会社さくらの家」の
      # 「の」は名前の一部です。**名前に使われる語を並べ、それが続く場合だけ
      # 「の」をまたぎます**（issue #153）。
      #
      # **一般名詞をすべて並べるのではありません。** 並べるのは、名前の後半に
      # 使われる語だけです。数は限られており、増やしても壊れません。
      def name_words_of(loaded, path)
        words = loaded[NAME_WORDS_KEY]
        unless words.is_a?(Array) && words.any? && words.all?(String)
          raise InvalidDefinitionError,
                "名前に使われる語の一覧がありません: #{path}" # 開発者向け
        end

        words.join('|')
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

      def build_rule(rule, name_words)
        patterns = fetch_required(rule, 'patterns')
        raise InvalidDefinitionError, "見つける語が空です: #{rule.inspect}" if patterns.empty? # 開発者向け

        {
          kind: fetch_required(rule, 'kind').to_sym,
          gloss: ensure_gloss(fetch_required(rule, 'gloss')),
          matchers: patterns.map { |pattern| matcher_for(pattern, name_words) }
        }
      end

      # **名前に使われる語の一覧を、手がかりへ差し込みます。**
      def matcher_for(pattern, name_words)
        Regexp.new(pattern.gsub(NAME_WORDS_PLACEHOLDER, name_words))
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
