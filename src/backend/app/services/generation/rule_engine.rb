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
  # 規則辞書の中身を検め、語を照合する仕事は AntiAiRules が持ちます。
  #
  # 適用した規則辞書の版を下書きへ記録します。あとから「どの版で作ったか」を
  # 追えるようにするためです（requirements.md 7.2）。
  class RuleEngine
    # 規則辞書が渡されていない場合に投げます。
    class MissingDictionaryError < StandardError; end

    # 規則辞書の内容が足りない、または壊れている場合に投げます。
    InvalidDictionaryError = AntiAiRules::InvalidDictionaryError

    # 渡された素材が文字列でない場合に投げます。
    class InvalidDraftError < StandardError; end

    # ノートに残す印です。文言ではなく記号で持ちます。
    REMOVED_NOTE_KIND = :anti_ai_removed

    def initialize(dictionary:)
      raise MissingDictionaryError, '規則辞書がありません。' if dictionary.nil? # 開発者向け

      @version = dictionary.version
      @rules = AntiAiRules.new(dictionary)
    end

    # 正規化済みの入力から、下書きを起こします。
    # @return [Draft]
    def start(input)
      Draft.new(input: input, dictionary_version: version)
    end

    # 規則を適用した下書きを返します。
    # @return [Draft]
    def apply(draft)
      kept, removed = partition(draft.main_terms)

      Trace.step('generation.anti_ai_rules_applied',
                 dictionary_version: version, kept: kept.size, removed: removed.size) do
        applied(draft, kept, removed)
      end
    end

    # 既定で避ける構図です。利用者が明示した場合のみ許します。
    delegate :avoided_compositions, to: :rules

    private

    attr_reader :version, :rules

    def applied(draft, kept, removed)
      draft.replace(
        main_terms: kept,
        negative_terms: (draft.negative_terms + rules.negative_terms).uniq,
        notes: draft.notes + removal_notes(removed),
        dictionary_version: version
      )
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
        ensure_material!(term)
        matched = rules.forbidden_match(term)
        matched.nil? ? kept << term : removed << { term: term, matched: matched }
      end

      [kept, removed]
    end

    def ensure_material!(term)
      return if term.is_a?(String)

      raise InvalidDraftError,
            "素材は文字列で渡してください: #{term.class}" # 開発者向け
    end

    def removal_notes(removed)
      removed.map do |entry|
        { kind: REMOVED_NOTE_KIND, term: entry[:term], matched: entry[:matched] }
      end
    end
  end
end
