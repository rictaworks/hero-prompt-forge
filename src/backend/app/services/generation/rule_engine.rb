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
  # **取り除いた語はノートへ残します。** 黙って消すと、利用者が指定したつもりの
  # 表現が反映されない理由を追えません。
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
    def partition(terms)
      terms.partition { |term| forbidden_terms.none? { |forbidden| term.include?(forbidden) } }
    end

    def removal_notes(removed)
      removed.map { |term| { kind: REMOVED_NOTE_KIND, term: term } }
    end
  end
end
