# frozen_string_literal: true

module Api
  module V1
    # 生成リクエストの受付と、結果の取り出しです（issue #55、#56）。
    #
    # **受付は 201 を返します。** 生成そのものは裏で走ります。
    # 画面は識別子を受け取り、結果を取りに来ます。
    #
    # **他人のリクエストは引けません。** 見つからない場合と同じ返し方にします。
    class PromptRequestsController < BaseController
      rescue_from Generation::InputNormalizer::InvalidInputError, with: :render_invalid_input
      rescue_from PromptRequests::Acceptance::ForbiddenInputError, with: :render_forbidden_input
      rescue_from Quota::Reservation::ExhaustedError, with: :render_quota_exhausted

      # 状態と、完了していれば 3 案を返します。
      def show
        found = PromptRequest.for_user(current_user).find(params.expect(:id))

        render json: PromptRequests::Representation.new(found).to_h, status: :ok
      end

      # 受け付けて、投入します。
      #
      # **`params.expect` で受け取ります。** `params.require` は配列を
      # そのまま通しますので、`project_id` に配列を送られると `find` が
      # 配列を返し、**契約の形を外れた 500 になります**
      # （PR #166 のレビューで実測されました）。
      def create
        request = acceptance.call(project_id: params.expect(:project_id),
                                  inputs: params.fetch(:inputs, {}))

        render json: PromptRequests::Representation.new(request).to_h, status: :created
      end

      private

      # **時刻の書き方は Rails の置き場から引きます。**
      # 文言の置き場（`labels`）へ書式を混ぜません（PR #166 のレビューより）。
      def spelled(time)
        I18n.l(time, format: :reset_at)
      end

      def acceptance
        PromptRequests::Acceptance.new(user: current_user)
      end

      # 入力の誤りです。**項目と理由だけを添えます。** 値を返しません。
      def render_invalid_input(error)
        render_error(code: 'invalid_input', scope: 'invalid_input',
                     status: :bad_request,
                     details: { fields: error.errors })
      end

      # 禁止入力です。**枠を使っていません。**
      def render_forbidden_input(error)
        render_error(code: 'forbidden_input', scope: 'forbidden_input',
                     status: :unprocessable_content,
                     details: { prompt_request_id: error.prompt_request.id,
                                reasons: error.reasons.map(&:to_h) })
      end

      # 本日の枠を使い切っています。**次回のリセット時刻を必ず添えます。**
      def render_quota_exhausted(error)
        render_error(code: 'quota_exhausted', scope: 'quota_exhausted',
                     status: :too_many_requests,
                     details: { reset_at: error.reset_at.iso8601 },
                     reset_at: spelled(error.reset_at))
      end
    end
  end
end
