# frozen_string_literal: true

# 利用者の認証です。
#
# セッションの識別子から利用者を特定します。
#
# 開発環境では、テストを可能にするため**認証済みへ分岐**できます。
# ただし次の条件をすべて満たす場合に限ります。
#
#   1. 実行中の環境が開発またはテストであること
#   2. 開発用の利用者を指す環境変数が設定されていること
#
# **本番では、環境変数を設定しても分岐しません。** 判定は環境のみに依存し、
# リクエスト側の値（ヘッダ・引数・クッキー）では切り替わりません。
# 本番の画面に、この分岐を使う導線を出しません。
module AuthenticatesUser
  extend ActiveSupport::Concern

  SESSION_COOKIE = :hpf_session

  included do
    before_action :authenticate_user!
  end

  private

  attr_reader :current_user, :current_session

  def authenticate_user!
    @current_user = authenticated_user
    return if @current_user

    render_api_error(
      code: 'unauthorized',
      message: I18n.t('errors.unauthorized.message'),
      next_action: I18n.t('errors.unauthorized.next_action'),
      status: :unauthorized
    )
  end

  # プラン値が有効であることを求めます。機能側はプラン値のみを参照します。
  def require_authorized_plan!
    return if current_user&.authorized?

    render_api_error(
      code: 'forbidden',
      message: I18n.t('errors.forbidden.message'),
      next_action: I18n.t('errors.forbidden.next_action'),
      status: :forbidden
    )
  end

  def authenticated_user
    session = Session.find_alive(cookies.signed[SESSION_COOKIE])
    if session
      @current_session = session
      return session.user
    end

    development_user
  end

  # 開発環境でのみ有効な分岐です。本番では必ず nil を返します。
  def development_user
    return nil unless AppEnvironment.developer_shortcuts_allowed?

    x_user_id = ENV.fetch('DEVELOPMENT_AUTO_LOGIN_X_USER_ID', nil)
    return nil if x_user_id.blank?

    User.find_by(x_user_id: x_user_id)
  end

  def render_api_error(code:, message:, next_action:, status:)
    error = ApiError.new(code: code, message: message, next_action: next_action,
                         status: status)
    render json: error.to_body, status: status
  end
end
