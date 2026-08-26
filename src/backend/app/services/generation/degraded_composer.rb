# frozen_string_literal: true

module Generation
  # 縮退合成です（requirements.md 4.2、issue #53）。
  #
  # **LLM が使えないときに、規則辞書だけで組み立てます。**
  # 磨きは入りませんが、**規則の適用・スタイルの仕様化・コピースペースの規定・
  # 矛盾の解決は、通常どおり行われます。** これらは規則辞書だけで完結します。
  #
  # **縮退した案には印を残します。** 印が無いと、利用者は「なぜ表現が
  # 素っ気ないのか」を知る手立てがありません。
  #
  # **黙って縮退しません。** 印はアートディレクションノート（issue #51）と
  # 出力の両方に残ります。
  class DegradedComposer
    # ノートに残す印です。
    NOTE_KIND = :degraded

    # 何回まで試すかです。**越えたら縮退します。**
    DEFAULT_ATTEMPTS = 2

    def initialize(refiner: LlmRefiner.new, attempts: DEFAULT_ATTEMPTS)
      @refiner = refiner
      @attempts = attempts
    end

    # 磨いた下書き、または縮退した下書きを返します。
    # @return [Draft]
    def compose(draft)
      return degraded(draft, :llm_unavailable) unless LlmRefiner.available?

      refined_with_retry(draft)
    end

    # その下書きが縮退したものかどうかを返します。
    def self.degraded?(draft)
      draft.notes.any? { |note| note[:kind] == NOTE_KIND && note[:degraded] }
    end

    private

    attr_reader :refiner, :attempts

    # **決めた回数だけ試します。** 越えたら縮退します。
    def refined_with_retry(draft)
      last = nil
      attempts.times do
        return refiner.refine(draft)
      rescue LlmRefiner::RequestFailedError, LlmRefiner::InvalidRefinementError => e
        last = e
      end

      degraded(draft, reason_for(last))
    end

    def reason_for(error)
      error.is_a?(LlmRefiner::InvalidRefinementError) ? :llm_unusable_result : :llm_failed
    end

    # **印を残します。** 黙って縮退しません。
    def degraded(draft, reason)
      Trace.step('generation.degraded', reason: reason, attempts: attempts) do
        draft.add(notes: [{ kind: NOTE_KIND, degraded: true, reason: reason }])
      end
    end
  end
end
