# frozen_string_literal: true

module Generation
  # 語の形をそろえます（issue #136）。
  #
  # アンチAIルック規則は、規則辞書の語と素材を照合します。**同じ意味の語でも、
  # 書き方が違うだけで取りこぼします。** 単数と複数、英国式と米国式のつづりは、
  # 語彙の問題ではなく書き方の問題ですので、照合の側で吸収します。
  #
  #   glowing particle effects -> glowing particle effect  （複数形をそろえます）
  #   over-saturated colours   -> over saturated color     （つづりをそろえます）
  #   smart, clean layout      -> smart clean layout       （前後の記号を落とします）
  #
  # **語順の違いと言い換えは、ここでは扱いません。** それらは語彙の問題ですので、
  # 規則辞書の側で語を足します（issue #65）。
  #
  # **語の切れ目で見る性質を壊しません。** そろえるのは語ごとで、語の並びは
  # そのままです。`teal` が `stealth` を巻き込まない性質は保たれます。
  class WordForms
    # 対応表の定義に誤りがある場合に投げます。
    class InvalidDefinitionError < StandardError; end

    DEFINITION_PATH = 'config/word_forms.yml'
    SPELLING_VARIANTS_KEY = 'spelling_variants'
    SINGULAR_WORDS_KEY = 'singular_words'

    # `s` で終わりますが複数形ではない語尾です。
    # `focus` ・ `analysis` ・ `canvas` ・ `glass` の末尾を落としません。
    SINGULAR_SUFFIXES = /(?:ss|us|is|as)\z/

    # `es` を丸ごと落とす語尾です。`boxes` は `box`、`dishes` は `dish` です。
    PLURAL_ES = /(?:ch|sh|x|z)es\z/

    # 英数字だけでできた語です。この形の語だけをそろえます。
    # 日本語には単数・複数の区別が無く、つづりの揺れも別の話です。
    ASCII_WORD = /\A[a-z0-9]+\z/

    # 語の前後に付く記号です。**語の一部として扱いません。**
    # 規則辞書へ `art,` と登録されると、記号ごと 1 つの語として照合され、
    # `smart, clean layout` が丸ごと落ちます（issue #136 で実測しました）。
    # 前後の記号を落とすと、`art` と `smart` は別の語として扱われます。
    SURROUNDING_MARKS = /\A[[:punct:]]+|[[:punct:]]+\z/

    class << self
      # 語の並びを、そろえた形にして返します。
      # @return [String]
      def canonical(text)
        text.split.map { |word| canonical_word(word) }.join(' ')
      end

      # 英国式のつづりを米国式へ寄せる対応表です。
      def spelling_variants
        definition[SPELLING_VARIANTS_KEY]
      end

      # `s` で終わりますが、複数形ではない語です。
      def singular_words
        definition[SINGULAR_WORDS_KEY]
      end

      # テストから読み直せるようにします。**本番の経路では使いません。**
      def reset!
        @definition = nil
      end

      private

      def canonical_word(word)
        bare = word.gsub(SURROUNDING_MARKS, '')
        return word unless bare.match?(ASCII_WORD)

        singular = singular_of(bare)
        spelling_variants.fetch(singular, singular)
      end

      # 複数形を単数形へ寄せます。
      #
      # **短い語は触りません。** `is` や `as` のような語まで削ると、
      # 別の語と同じ形になります。
      # **`ss` ・ `us` ・ `is` ・ `as` で終わる語も触りません。**
      # `glass` ・ `focus` ・ `analysis` ・ `canvas` は複数形ではありません。
      # それ以外の例外（`lens` など）は設定ファイルに書きます。
      def singular_of(word)
        return word unless plural?(word)
        return "#{word[0..-4]}y" if word.end_with?('ies')
        return word[0..-3] if word.match?(PLURAL_ES)

        word[0..-2]
      end

      # 複数形かどうかを見分けます。
      def plural?(word)
        return false if word.length <= 3 || singular_words.include?(word)
        return false unless word.end_with?('s')
        return true if word.end_with?('ies') && word.length > 4

        !word.match?(SINGULAR_SUFFIXES)
      end

      def definition
        @definition ||= load_definition
      end

      def load_definition
        loaded = read_definition
        variants = loaded[SPELLING_VARIANTS_KEY]
        singulars = loaded[SINGULAR_WORDS_KEY]
        ensure_variants!(variants)
        ensure_singulars!(singulars)

        { SPELLING_VARIANTS_KEY => variants.freeze,
          SINGULAR_WORDS_KEY => singulars.freeze }.freeze
      end

      def read_definition
        loaded = YAML.safe_load_file(Rails.root.join(DEFINITION_PATH))
        return loaded if loaded.is_a?(Hash)

        raise InvalidDefinitionError,
              "語の形の対応表が読めません: #{DEFINITION_PATH}" # 開発者向け
      rescue Errno::ENOENT, Psych::SyntaxError => e
        raise InvalidDefinitionError,
              "語の形の対応表を読み込めません: #{DEFINITION_PATH} (#{e.class})" # 開発者向け
      end

      # **中身を検めます。** 対応表は人が編集するデータです。
      # 空の語や文字列でない値が混ざると、照合が静かに壊れます。
      def ensure_variants!(variants)
        unless variants.is_a?(Hash) && variants.any?
          raise InvalidDefinitionError,
                "語の形の対応表がありません: #{DEFINITION_PATH}" # 開発者向け
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
