# frozen_string_literal: true

module Generation
  # アンチAIルック規則の適用です（requirements.md 4.1 の 2、4.2）。
  #
  # AI が作った画像にありがちな表現（クリシェ配色・意味の無い浮遊物・過剰な彩度）を、
  # 二方向から抑えます。
  #
  #   1. メインプロンプトから、規則辞書の「排除する語」を取り除きます
  #   2. ネガティブプロンプトへ、規則辞書の「注入する語」を必ず入れます
  #
  # **取り除いた素材と、当たった語の両方をノートへ残します。** 素材だけでは、
  # どのクリシェに当たって消えたのかを追えません。黙って消すと、利用者が指定した
  # つもりの表現が反映されない理由が分かりません。
  #
  # 語の照合は、表記のゆれを取り除いてから行います。大文字と小文字の違い・連続する
  # 空白・ハイフンは「同じ語の別の書き方」です。`Purple to teal gradient` と
  # `purple to teal gradient` は同じものを指します。
  #
  # 適用した規則辞書の版を下書きへ記録します。あとから「どの版で作ったか」を
  # 追えるようにするためです（requirements.md 7.2）。
  class RuleEngine
    # 規則辞書が渡されていない場合に投げます。
    class MissingDictionaryError < StandardError; end

    # 規則辞書の内容が足りない場合に投げます。
    class InvalidDictionaryError < StandardError; end

    # 排除する語の鍵です。
    FORBIDDEN_TERMS_KEY = 'forbidden_terms'
    # 注入する語の鍵です。
    NEGATIVE_TERMS_KEY = 'negative_prompt_terms'
    # 既定で避ける構図の鍵です。
    AVOIDED_COMPOSITIONS_KEY = 'avoided_compositions'

    # ノートに残す印です。文言ではなく記号で持ちます。
    REMOVED_NOTE_KIND = :anti_ai_removed

    # 表記のゆれを取り除く際に、空白として扱う記号です。
    WORD_SEPARATORS = /[-_\u3000\s]+/

    def initialize(dictionary:)
      raise MissingDictionaryError, '規則辞書がありません。' if dictionary.nil? # 開発者向け

      @dictionary = dictionary
      @rules = dictionary.anti_ai_rules
      ensure_rules!
    end

    # 正規化済みの入力から、下書きを起こします。
    # @return [Draft]
    def start(input)
      Draft.new(input: input, dictionary_version: dictionary.version)
    end

    # 規則を適用した下書きを返します。
    # @return [Draft]
    def apply(draft)
      kept, removed = partition(draft.main_terms)

      draft.replace(
        main_terms: kept,
        negative_terms: (draft.negative_terms + negative_terms).uniq,
        notes: draft.notes + removal_notes(removed),
        dictionary_version: dictionary.version
      )
    end

    # 表記のゆれを取り除きます。照合の前に、両側へ同じ手当てをします。
    def self.normalize(term)
      term.to_s.downcase.gsub(WORD_SEPARATORS, ' ').strip
    end

    # 既定で避ける構図です。利用者が明示した場合のみ許します。
    def avoided_compositions
      Array(rules[AVOIDED_COMPOSITIONS_KEY])
    end

    private

    attr_reader :dictionary, :rules

    def ensure_rules!
      return if rules.is_a?(Hash) &&
                rules[FORBIDDEN_TERMS_KEY].is_a?(Array) &&
                rules[NEGATIVE_TERMS_KEY].is_a?(Array)

      raise InvalidDictionaryError,
            "規則辞書のアンチAIルックの定義が足りません: #{dictionary.version}" # 開発者向け
    end

    def forbidden_terms
      rules.fetch(FORBIDDEN_TERMS_KEY)
    end

    def negative_terms
      rules.fetch(NEGATIVE_TERMS_KEY)
    end

    # 排除する語を含む素材を取り除きます。語そのものだけでなく、語を含む
    # 言い回しも対象にします。「purple to teal gradient background」のように
    # 前後へ足された形で入り込むためです。
    #
    # 取り除いた素材には、**当たった語を添えて**返します。
    def partition(terms)
      kept = []
      removed = []

      terms.each do |term|
        matched = matched_forbidden(term)
        matched.nil? ? kept << term : removed << { term: term, matched: matched }
      end

      [kept, removed]
    end

    # その素材が、どの排除する語に当たるかを返します。当たらなければ空です。
    def matched_forbidden(term)
      normalized = self.class.normalize(term)

      forbidden_terms.find { |forbidden| normalized.include?(self.class.normalize(forbidden)) }
    end

    def removal_notes(removed)
      removed.map do |entry|
        { kind: REMOVED_NOTE_KIND, term: entry[:term], matched: entry[:matched] }
      end
    end
  end
end
