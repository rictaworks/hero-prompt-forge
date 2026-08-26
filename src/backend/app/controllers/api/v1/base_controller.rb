# frozen_string_literal: true

module Api
  module V1
    # API の共通の入口です（SPEC/api/README.md）。
    #
    # **すべての失敗で同じ形を返します。** 曖昧なエラーを返しません。
    # 利用者へ見せる文言と、次に行う操作を必ず含めます。
    #
    # **他人の資源へは 403 ではなく 404 を返します。** 存在の有無を
    # 知らせないためです。
    #
    # **握りつぶしません。** ここで受け止めるのは、利用者へ返し方が決まって
    # いる失敗だけです。想定外はそのまま外へ出し、記録に残します。
    class BaseController < ApplicationController
      include AuthenticatesUser

      before_action :require_authorized_plan!

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

      private

      # 見つからない場合です。**他人の資源も同じ返し方にします。**
      def render_not_found
        render_error(code: 'not_found', scope: 'not_found', status: :not_found)
      end

      # 文言は `config/locales/ja.yml` から引きます。
      def render_error(code:, scope:, status:, details: {}, **interpolations)
        error = ApiError.new(code: code,
                             message: I18n.t("errors.#{scope}.message", **interpolations),
                             next_action: I18n.t("errors.#{scope}.next_action",
                                                 **interpolations),
                             status: status,
                             details: details)
        render json: error.to_body, status: status
      end
    end
  end
end
