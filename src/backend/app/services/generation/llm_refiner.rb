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

    def initialize(client: GeminiClient.new, settings: LlmSettings.load)
      @client = client
      @settings = settings
    end

    # API キーが用意されているかどうかを返します。
    def self.available?
      GeminiClient.available?
    end

    # 磨いた下書きを返します。
    # @return [Draft]
    def refine(draft)
      lines = draft.main_terms
      return draft if lines.empty?

      refined = client.refine(instruction: settings.fetch('instruction'), lines: lines)
      ensure_refinement!(draft, refined)

      applied(draft, refined)
    end

    private

    attr_reader :client, :settings

    def applied(draft, refined)
      Trace.step('generation.llm_refined',
                 model: settings.fetch('model'), lines: refined.size) do
        draft.replace(main_terms: refined)
             .add(notes: [{ kind: NOTE_KIND, model: settings.fetch('model'),
                            lines: refined.size }])
      end
    end

    # **磨いたつもりで壊れている状態を残しません。**
    def ensure_refinement!(draft, refined)
      ensure_size!(draft, refined)
      ensure_english!(refined)
      ensure_copy_space!(draft, refined)
    end

    def ensure_size!(draft, refined)
      return if refined.size == draft.main_terms.size

      raise InvalidRefinementError,
            "素材の数が変わりました: #{draft.main_terms.size} -> #{refined.size}" # 開発者向け
    end

    def ensure_english!(refined)
      return if refined.none? { |line| line.match?(JAPANESE) }

      raise InvalidRefinementError, '磨いた素材に日本語が混ざりました。' # 開発者向け
    end

    # **コピースペースの指定は最上位です**（requirements.md 4.1 の 5、4.2）。
    def ensure_copy_space!(draft, refined)
      return unless CopySpace.reserved?(draft)
      return if refined.any? { |line| line.include?(CopySpace::RESERVED_MARK) }

      raise InvalidRefinementError, '磨いた素材から余白の指定が消えました。' # 開発者向け
    end
  end
end
