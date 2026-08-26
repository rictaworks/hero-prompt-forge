# frozen_string_literal: true

module Generation
  # アンチAIルック規則です（requirements.md 4.2）。
  #
  # 規則辞書の中身を検め、照合できる形へ整えます。**規則辞書は人が編集する
  # データです（requirements.md 4.3）。中身を信用しません。** 空の語が 1 つ
  # 混ざるだけで、すべての素材に当たってメインプロンプトが消えます。
  #
  # 語の照合には 2 つの手当てをします。
  #
  #   - 表記のゆれを取り除きます。大文字と小文字・連続する空白・ハイフンは
  #     「同じ語の別の書き方」です
  #   - **英字の語は、語の切れ目で見ます。** `teal` を登録したときに `stealth` を
  #     巻き込まないためです。日本語には語の切れ目がないため、そのまま含みを見ます
  class AntiAiRules
    # 規則辞書の内容が足りない、または壊れている場合に投げます。
    class InvalidDictionaryError < StandardError; end

    # 排除する語の鍵です。
    FORBIDDEN_TERMS_KEY = 'forbidden_terms'
    # 注入する語の鍵です。
    NEGATIVE_TERMS_KEY = 'negative_prompt_terms'
    # 既定で避ける構図の鍵です。
    AVOIDED_COMPOSITIONS_KEY = 'avoided_compositions'

    # 表記のゆれを取り除く際に、空白として扱う記号です。
    WORD_SEPARATORS = /[-_　\s]+/

    # 英数字だけでできた語です。この形の語は、語の切れ目で照合します。
    ASCII_TERM = /\A[a-z0-9 ]+\z/

    def initialize(dictionary)
      @version = dictionary.version
      @rules = dictionary.anti_ai_rules
      ensure_rules!
      @matchers = forbidden_terms.map { |term| [term, matcher_for(term)] }
    end

    # 表記のゆれを取り除きます。照合の前に、両側へ同じ手当てをします。
    def self.normalize(term)
      term.to_s.downcase.gsub(WORD_SEPARATORS, ' ').strip
    end

    # その素材が、どの排除する語に当たるかを返します。当たらなければ空です。
    def forbidden_match(term)
      normalized = self.class.normalize(term)

      found = @matchers.find do |_original, matcher|
        matcher.is_a?(Regexp) ? normalized.match?(matcher) : normalized.include?(matcher)
      end

      found&.first
    end

    def negative_terms
      @rules.fetch(NEGATIVE_TERMS_KEY)
    end

    # 既定で避ける構図です。利用者が明示した場合のみ許します。
    # **複製して返します。** そのまま返すと、呼び出す側から規則の中身を書き換えられます。
    def avoided_compositions
      Array(@rules[AVOIDED_COMPOSITIONS_KEY]).dup
    end

    private

    def forbidden_terms
      @rules.fetch(FORBIDDEN_TERMS_KEY)
    end

    def ensure_rules!
      unless @rules.is_a?(Hash)
        raise InvalidDictionaryError,
              "規則辞書のアンチAIルックの定義がありません: #{@version}" # 開発者向け
      end

      ensure_terms!(FORBIDDEN_TERMS_KEY)
      ensure_terms!(NEGATIVE_TERMS_KEY)
    end

    def ensure_terms!(key)
      terms = @rules[key]
      unless terms.is_a?(Array)
        raise InvalidDictionaryError,
              "規則辞書の #{key} が一覧ではありません: #{@version}" # 開発者向け
      end

      terms.each { |term| ensure_term!(key, term) }
    end

    # **空の語・空白だけの語・文字列でない語を通しません。**
    # 空の語は、すべての素材に当たってメインプロンプトを消します。
    def ensure_term!(key, term)
      unless term.is_a?(String)
        raise InvalidDictionaryError,
              "規則辞書の #{key} に文字列でない語があります: #{term.class}" # 開発者向け
      end

      return unless self.class.normalize(term).empty?

      raise InvalidDictionaryError,
            "規則辞書の #{key} に空の語があります: #{@version}" # 開発者向け
    end

    # 語の形に合わせた照合の仕方を返します。
    #
    # 英数字だけでできた語は、**語の切れ目で見ます。** `teal` が `stealth` の
    # 内側に当たると、まったく関係のない指示まで消えます。
    # 日本語には語の切れ目がないため、そのまま含みを見ます。
    def matcher_for(term)
      normalized = self.class.normalize(term)
      return normalized unless normalized.match?(ASCII_TERM)

      /(?<![a-z0-9])#{Regexp.escape(normalized)}(?![a-z0-9])/
    end
  end
end
