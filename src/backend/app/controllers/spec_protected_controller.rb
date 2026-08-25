# frozen_string_literal: true

# 認証の振る舞いを検証するための経路です。
#
# テストからのみ経路を割り当てます。本番の経路表には現れません。
class SpecProtectedController < ApplicationController
  include AuthenticatesUser

  before_action :require_authorized_plan!, only: :authorized

  def show
    render json: { x_user_id: current_user.x_user_id }
  end

  def authorized
    render json: { x_user_id: current_user.x_user_id }
  end
end
