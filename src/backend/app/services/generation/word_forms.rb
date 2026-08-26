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
    PLURAL_FORMS_KEY = 'plural_forms'

    # `s` で終わりますが複数形ではない語尾です。
    # `focus` ・ `analysis` ・ `canvas` ・ `glass` の末尾を落としません。
    SINGULAR_SUFFIXES = /(?:ss|us|is|as)\z/

    # `es` を丸ごと落とす語尾です。`boxes` は `box`、`dishes` は `dish` です。
    PLURAL_ES = /(?:ch|sh|x|z)es\z/

    # 英数字だけでできた語です。この形の語だけをそろえます。
    # 日本語には単数・複数の区別が無く、つづりの揺れも別の話です。
    ASCII_WORD = /\A[a-z0-9]+\z/

    # そろえた理由の印です。文言ではなく記号で持ちます。
    #
    # **記録へ利用者の入力そのものを入れません。** どの語がどう変わったかを
    # 値で残すと、利用者の入力が記録へ流れます。**どの規則が何件働いたか**を
    # 残します（issue #148）。
    MARKS_REMOVED = :marks
    PLURAL_TO_SINGULAR = :plural
    SPELLING_UNIFIED = :spelling

    # 語の前後に付く記号です。**語の一部として扱いません。**
    # 規則辞書へ `art,` と登録されると、記号ごと 1 つの語として照合され、
    # `smart, clean layout` が丸ごと落ちます（issue #136 で実測しました）。
    # 前後の記号を落とすと、`art` と `smart` は別の語として扱われます。
    SURROUNDING_MARKS = /\A[[:punct:]]+|[[:punct:]]+\z/

    class << self
      # 語の並びを、そろえた形にして返します。
      # @return [String]
      def canonical(text)
        applied = Hash.new(0)
        canonical = text.split.map { |word| canonical_word(word, applied) }.join(' ')
        return canonical if applied.empty?

        traced(applied) { canonical }
      end

      # 英国式のつづりを米国式へ寄せる対応表です。
      def spelling_variants
        definition[SPELLING_VARIANTS_KEY]
      end

      # `s` で終わりますが、複数形ではない語です。
      def singular_words
        definition[SINGULAR_WORDS_KEY]
      end

      # 末尾の規則では単数形へ戻せない複数形です。
      def plural_forms
        definition[PLURAL_FORMS_KEY]
      end

      # テストから読み直せるようにします。**本番の経路では使いません。**
      def reset!
        @definition = nil
      end

      private

      # **そろえた事実を記録へ残します。** どの語がなぜ消えたかを追うとき、
      # どの規則が働いたかが分からないと、規則辞書と素材のどちらを直せばよいか
      # 決められません（issue #148）。
      def traced(applied, &)
        Trace.step('generation.word_forms_normalized',
                   marks: applied[MARKS_REMOVED],
                   plural: applied[PLURAL_TO_SINGULAR],
                   spelling: applied[SPELLING_UNIFIED], &)
      end

      def canonical_word(word, applied)
        bare = word.gsub(SURROUNDING_MARKS, '')
        return word unless bare.match?(ASCII_WORD)

        applied[MARKS_REMOVED] += 1 unless bare == word
        singular = singular_of(bare)
        applied[PLURAL_TO_SINGULAR] += 1 unless singular == bare
        unified = spelling_variants.fetch(singular, singular)
        applied[SPELLING_UNIFIED] += 1 unless unified == singular

        unified
      end

      # 複数形を単数形へ寄せます。
      #
      # **対応表を先に引きます。** 語尾の規則では見分けられない語があるためです
      # （`lenses` は `lens`、`houses` は `house` です。どちらも `ses` で
      # 終わります）。
      #
      # **短い語は触りません。** `is` や `as` のような語まで削ると、
      # 別の語と同じ形になります。
      # **`ss` ・ `us` ・ `is` ・ `as` で終わる語も触りません。**
      # `glass` ・ `focus` ・ `analysis` ・ `canvas` は複数形ではありません。
      # それ以外の例外（`lens` など）は設定ファイルに書きます。
      def singular_of(word)
        known = plural_forms[word]
        return known if known
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
        @definition ||= WordFormsTable.load
      end
    end
  end
end
