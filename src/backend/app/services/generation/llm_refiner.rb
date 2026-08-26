# frozen_string_literal: true

module Generation
  # LLM による精緻化です（requirements.md 4.1 の 10）。
  #
  # **表現を磨くだけです。** 素材の数と並びを変えません。変わると、どの素材が
  # どの段のものかを追えなくなり、控えと実物が食い違います。
  #
  # **送るのは、磨く対象の英文だけです。** 認証情報・利用者の識別子・
  # セッションを送りません。**サービス概要もそのままは送りません。**
  # 概要には第三者の名前が入り得ますので、**規則を通したあとの素材だけ**を送ります。
  #
  # **日本語を含む素材は送りません。** 日本語固有名詞は、読みが決まらない場合に
  # 元の表記のまま素材へ入ります（requirements.md 4.1 の 6）。送って磨かせると、
  # **別のお名前になります。** そのまま残し、英文の素材だけを磨きます
  # （PR #162 のレビューより）。
  #
  # **返ってきた内容を検めます。** 数が変わった場合・日本語が混ざった場合・
  # コピースペースの指定が消えた場合は、その場で失敗させます。
  # **磨いたつもりで壊れている状態を残しません。**
  #
  # **失敗したら、そのまま投げます。** 縮退（issue #53）が受け止めます。
  class LlmRefiner
    # 磨いた結果が受け取れない形の場合に投げます。
    class InvalidRefinementError < StandardError; end

    # 呼び出しが失敗した場合に投げます。
    RequestFailedError = GeminiClient::RequestFailedError

    # ノートに残す印です。
    NOTE_KIND = :llm_refined

    # 日本語が混ざっていないかを見ます。
    JAPANESE = /[ぁ-んァ-ヶ一-龥]/

    # @param dictionary [RuleDictionary, nil] アンチAIルック規則の再検査に使います
    def initialize(client: GeminiClient.new, settings: LlmSettings.load, dictionary: nil)
      @client = client
      @settings = settings
      @rules = dictionary && AntiAiRules.new(dictionary)
    end

    # API キーが用意されているかどうかを返します。
    def self.available?
      GeminiClient.available?
    end

    # 磨いた下書きを返します。
    # @return [Draft]
    def refine(draft)
      targets = refinable(draft.main_terms)
      return draft if targets.empty?

      refined = client.refine(instruction: settings.fetch('instruction'), lines: targets)
      ensure_refinement!(targets, refined)
      terms = merged(draft.main_terms, targets, refined)
      ensure_copy_space!(draft, terms)

      applied(draft, terms)
    end

    # 磨く対象です。**日本語を含む素材は外します。**
    def refinable(terms)
      terms.grep_v(JAPANESE)
    end

    # 磨いた素材を、もとの並びへ戻します。**並びも件数も変えません。**
    def merged(terms, targets, refined)
      replacements = targets.zip(refined).to_h

      terms.map { |term| replacements.fetch(term, term) }
    end

    private

    attr_reader :client, :settings, :rules

    # **素材の数を変えません。**
    #
    # **`add` を使いません。** `Draft#add` は同じ語を重ねませんので、
    # 磨いた結果に同じ文が 2 つあると、**数を検めたあとで黙って減ります**
    # （PR #162 のレビューより）。控えごと差し替えます。
    def applied(draft, terms)
      note = { kind: NOTE_KIND, model: settings.fetch('model'), lines: terms.size }

      Trace.step('generation.llm_refined',
                 model: settings.fetch('model'), lines: terms.size) do
        draft.replace(main_terms: terms, notes: draft.notes + [note])
      end
    end

    # **磨いたつもりで壊れている状態を残しません。**
    def ensure_refinement!(targets, refined)
      ensure_size!(targets, refined)
      ensure_english!(refined)
      ensure_allowed!(refined)
    end

    def ensure_size!(targets, refined)
      return if refined.size == targets.size

      raise InvalidRefinementError,
            "素材の数が変わりました: #{targets.size} -> #{refined.size}" # 開発者向け
    end

    # **コピースペースの指定は最上位です**（requirements.md 4.1 の 5、4.2）。
    # 言い回しを磨く過程で消えることがありますので、磨いたあとに確かめます。
    def ensure_copy_space!(draft, terms)
      return unless CopySpace.reserved?(draft)
      return if terms.any? { |line| line.include?(CopySpace::RESERVED_MARK) }

      raise InvalidRefinementError, '磨いた素材から余白の指定が消えました。' # 開発者向け
    end

    # **磨いた素材を、もう一度アンチAIルック規則へ当てます。**
    # 磨く過程で、排除するはずの語が戻ることがあります
    # （PR #162 のレビューより）。**戻ったら、その場で失敗させます。**
    def ensure_allowed!(refined)
      return if rules.nil?

      matched = refined.filter_map { |line| rules.forbidden_match(line) }.uniq
      return if matched.empty?

      raise InvalidRefinementError,
            "磨いた素材へ排除する語が戻りました: #{matched.join(', ')}" # 開発者向け
    end

    def ensure_english!(refined)
      return if refined.none? { |line| line.match?(JAPANESE) }

      raise InvalidRefinementError, '磨いた素材に日本語が混ざりました。' # 開発者向け
    end
  end
end
