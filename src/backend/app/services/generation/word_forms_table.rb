# frozen_string_literal: true

module Generation
  # 語の形の対応表の読み込みと検めです（issue #136、#148）。
  #
  # **対応表は人が編集するデータです。中身を信用しません。**
  # 空の語や文字列でない値が混ざると、照合が静かに壊れます。
  #
  # **起動時に読み込みます。** 遅延読み込みのままだと、壊れていることに
  # 最初の生成まで気づけません。**お客さまがお申し込みになった瞬間に落ちます**
  # （issue #148）。読み込みは `config/initializers/generation_definitions.rb` です。
  class WordFormsTable
    InvalidDefinitionError = WordForms::InvalidDefinitionError

    DEFINITION_PATH = WordForms::DEFINITION_PATH
    SPELLING_VARIANTS_KEY = WordForms::SPELLING_VARIANTS_KEY
    SINGULAR_WORDS_KEY = WordForms::SINGULAR_WORDS_KEY
    PLURAL_FORMS_KEY = WordForms::PLURAL_FORMS_KEY

    # 対応表に書ける語の形です。**英小文字と数字だけです。**
    ASCII_WORD = WordForms::ASCII_WORD

    class << self
      # @return [Hash]
      def load
        loaded = read_definition
        variants = loaded[SPELLING_VARIANTS_KEY]
        singulars = loaded[SINGULAR_WORDS_KEY]
        plurals = loaded[PLURAL_FORMS_KEY]
        ensure_variants!(variants, SPELLING_VARIANTS_KEY)
        ensure_variants!(plurals, PLURAL_FORMS_KEY)
        ensure_singulars!(singulars)

        DeepFreeze.call({ SPELLING_VARIANTS_KEY => variants,
                          SINGULAR_WORDS_KEY => singulars,
                          PLURAL_FORMS_KEY => plurals })
      end

      private

      def read_definition
        loaded = YAML.safe_load_file(Rails.root.join(DEFINITION_PATH))
        return loaded if loaded.is_a?(Hash)

        raise InvalidDefinitionError,
              "語の形の対応表が読めません: #{DEFINITION_PATH}" # 開発者向け
      rescue Errno::ENOENT, Psych::SyntaxError => e
        raise InvalidDefinitionError,
              "語の形の対応表を読み込めません: #{DEFINITION_PATH} (#{e.class})" # 開発者向け
      end

      def ensure_variants!(variants, key)
        unless variants.is_a?(Hash) && variants.any?
          raise InvalidDefinitionError,
                "語の形の対応表がありません: #{key} (#{DEFINITION_PATH})" # 開発者向け
        end

        variants.each do |from, to|
          next if valid_pair?(from, to)

          raise InvalidDefinitionError,
                "語の形の対応表に使えない値があります: #{from.inspect} -> #{to.inspect}" # 開発者向け
        end
      end

      def ensure_singulars!(singulars)
        return if singulars.is_a?(Array) &&
                  singulars.all? { |word| word.is_a?(String) && word.match?(ASCII_WORD) }

        raise InvalidDefinitionError,
              "複数形でない語の一覧が読めません: #{DEFINITION_PATH}" # 開発者向け
      end

      def valid_pair?(from, to)
        [from, to].all? { |value| value.is_a?(String) && value.match?(ASCII_WORD) } && from != to
      end
    end
  end
end
