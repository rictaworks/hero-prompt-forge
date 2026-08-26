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
      include VerifiesHumans

      rescue_from Generation::InputNormalizer::InvalidInputError, with: :render_invalid_input
      rescue_from PromptRequests::Acceptance::ForbiddenInputError, with: :render_forbidden_input
      rescue_from Quota::Reservation::ExhaustedError, with: :render_quota_exhausted
      rescue_from BotProtection::RecaptchaVerifier::VerificationFailedError,
                  with: :render_verification_failed
      rescue_from BotProtection::RecaptchaVerifier::UnavailableError,
                  with: :render_verification_unavailable

      # **投入する経路だけを守ります。** 閲覧は守りません。
      #
      #   1. **守る対象は「投入」です。** 閲覧は状態を変えず、枠も使いません
      #   2. **閲覧はすでに認証とプラン値で守られています**
      #   3. 画面を移るたびに問い合わせると、待ち時間と第三者への送信が増えます
      #
      # 判断の正は `SPEC/api/README.md` です。
      before_action :verify_human!, only: :create

      # 生成履歴です（issue #59）。
      #
      # **上限に達していても閲覧できます。** 閲覧は生成ではありません。
      # 枠の判定をこの経路に置きません。
      #
      # **他人のリクエストは載りません。** 必ず利用者で絞り込みます。
      def index
        found = owned.recent_first.includes(:prompt_outputs)
        found = found.where(project_id: project_ids) if params[:project_id].present?

        render json: { prompt_requests: found.map { |item| summary(item) } }, status: :ok
      end

      # 状態と、完了していれば 3 案を返します。
      def show
        render json: PromptRequests::Representation.new(owned.find(params.expect(:id))).to_h,
               status: :ok
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

      # **必ず利用者で絞り込みます。** 絞り込みを飛ばす経路を作りません。
      def owned
        PromptRequest.for_user(current_user)
      end

      # **他人のプロジェクトの識別子で絞られても、何も返しません。**
      # 絞り込みは `owned` の内側で行いますので、範囲が広がりません。
      def project_ids
        Array(params[:project_id])
      end

      def summary(prompt_request)
        PromptRequests::Representation.new(prompt_request).to_summary
      end

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

      # 人の操作だと確かめられませんでした。
      #
      # **通らなかった理由を返しません。** Google が返す理由の符号は、
      # Bot 対策の内側の情報です。**返すと、通り抜け方を探る手がかりになります。**
      def render_verification_failed(_error)
        render_error(code: 'human_verification_failed', scope: 'human_verification_failed',
                     status: :forbidden)
      end

      # 照合そのものができませんでした。**利用者の落ち度ではありません。**
      def render_verification_unavailable(_error)
        render_error(code: 'service_unavailable', scope: 'service_unavailable',
                     status: :service_unavailable)
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
