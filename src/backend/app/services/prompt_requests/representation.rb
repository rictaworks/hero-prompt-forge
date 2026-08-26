# frozen_string_literal: true

module PromptRequests
  # 生成リクエストを、API の応答の形へ直します（issue #56）。
  #
  # **状態は requirements.md 12.1 の名前をそのまま返します。** 画面側で
  # 読み替える必要が無いようにします。
  #
  # **案は、成果物を提供した状態のときだけ返します。** 途中の状態で案を
  # 返すと、3 案そろう前の中途半端な内容が画面へ出ます。
  #
  # **縮退で作られた案には印が付きます**（requirements.md 4.2）。
  # 印はリクエストと案の両方から引けます。
  #
  # **差し戻した理由の中身を返しません。** 記録に残るのは開発者向けの
  # 種別です。利用者へは、文言と次に行う操作を返します。
  class Representation
    # 成果物を返す状態です。
    DELIVERED = PromptRequest::DELIVERED_STATUSES

    # 利用者へ理由を添える状態です。
    EXPLAINED = %w[rejected failed].freeze

    # 常に返す項目です。
    #
    # **どのプロジェクトのものかも返します。** 一覧から辿れないと、
    # 過去案の再表示ができません（PR #167 のレビューより）。
    BASE_FIELDS = %i[
      id project_id status degraded target_model dictionary_version
    ].freeze

    def initialize(prompt_request)
      @prompt_request = prompt_request
    end

    # 履歴の一覧に載せる形です（issue #59）。
    #
    # **案そのものを載せません。** 一覧で 3 案ぶんの本文を返すと、
    # 件数が増えるほど応答が重くなります。**取り出しは 1 件ずつ行います。**
    #
    # **縮退の印は載せます。** 履歴からも、どの案が縮退で作られたかが分かります。
    # @return [Hash]
    def to_summary
      base.merge(outputs_count: prompt_request.prompt_outputs.size)
    end

    # @return [Hash]
    def to_h
      body = base
      body[:outputs] = outputs if DELIVERED.include?(prompt_request.status)
      body[:failure] = failure if EXPLAINED.include?(prompt_request.status)
      body
    end

    private

    attr_reader :prompt_request

    def base
      prompt_request.slice(*BASE_FIELDS).symbolize_keys.merge(
        created_at: prompt_request.created_at.iso8601,
        updated_at: prompt_request.updated_at.iso8601
      )
    end

    def outputs
      prompt_request.prompt_outputs.in_order.map { |output| output_of(output) }
    end

    def output_of(output)
      {
        variation_no: output.variation_no,
        composition_type: output.composition_type,
        main_prompt: output.main_prompt,
        negative_prompt: output.negative_prompt,
        parameters: output.parameters,
        art_direction_note: JSON.parse(output.art_direction_note),
        degraded: output.degraded?
      }
    end

    # **理由は文言で返します。** 記録の中身をそのまま出しません。
    def failure
      {
        code: prompt_request.status,
        message: I18n.t("prompt_requests.failure.#{prompt_request.status}.message"),
        next_action: I18n.t("prompt_requests.failure.#{prompt_request.status}.next_action")
      }
    end
  end
end
