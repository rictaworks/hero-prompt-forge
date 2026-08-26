# frozen_string_literal: true

module Api
  module V1
    # いまログインしている利用者です（issue #70）。
    #
    # **画面の上部バーが、表示名とプラン値を出すために使います。**
    # 画面に値を持たせず、その都度ここから引きます。
    #
    # **プラン値の判定を求めません。** `pending` の方も自分の状態を
    # 見られる必要があります。**見られないと、なぜ使えないのかが
    # 分かりません。** 認証だけを求めます。
    #
    # **返すのは表示名とプラン値だけです。** X のユーザー ID を返しません。
    # 画面に出す必要が無く、他の利用者を辿る手がかりになります。
    class SessionController < BaseController
      # **プラン値の判定を外します。** 認証だけを求めます。
      skip_before_action :require_authorized_plan!

      def show
        render json: {
          display_name: current_user.display_name,
          plan: current_user.plan
        }, status: :ok
      end
    end
  end
end
