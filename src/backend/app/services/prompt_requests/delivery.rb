# frozen_string_literal: true

module PromptRequests
  # 出来上がった 3 案を、生成リクエストへ収めます（requirements.md 4.2、12.1）。
  #
  # **保存と状態の更新を、ひとまとまりにします。** 途中で落ちると、
  # 案だけがあって状態が進んでいない記録が残ります。
  #
  # **クォータの確定は、このひとまとまりの外です。** 枠は別の持ち場の記録
  # ですので、同じ取引にすると片方の失敗でもう片方が巻き戻ります。
  # 外れた場合の拾い直しは、投入し直し（`GeneratePromptJob`）が行います。
  class Delivery
    # 案がそろわなかった場合に投げます。
    class IncompletePackagesError < StandardError; end

    def initialize(prompt_request)
      @prompt_request = prompt_request
    end

    # @param packages [Array<Generation::PromptPackage>] 3 案です
    # @return [PromptRequest]
    def call(packages)
      ensure_complete!(packages)

      PromptRequest.transaction do
        packages.each { |package| store(package) }
        prompt_request.transition_to!(status_for(packages),
                                      degraded: degraded?(packages),
                                      dictionary_version: version_of(packages))
      end

      prompt_request
    end

    private

    attr_reader :prompt_request

    # **案がそろっていなければ、その場で失敗させます。**
    # 数が足りないまま保存すると、画面は 3 案そろわない結果を受け取ります。
    def ensure_complete!(packages)
      return if packages.size == PromptOutput::VARIATION_COUNT

      raise IncompletePackagesError,
            "案の数が足りません: #{packages.size}" # 開発者向け
    end

    def degraded?(packages)
      packages.any?(&:degraded?)
    end

    def status_for(packages)
      degraded?(packages) ? 'degraded_completed' : 'completed'
    end

    def version_of(packages)
      packages.fetch(0).draft.dictionary_version
    end

    def store(package)
      PromptOutput.create!(prompt_request: prompt_request,
                           variation_no: package.number,
                           composition_type: package.composition_type,
                           main_prompt: package.formatted.to_prompt,
                           negative_prompt: package.formatted.negative_prompt,
                           parameters: package.formatted.parameters,
                           art_direction_note: package.note.to_h.to_json)
    end
  end
end
