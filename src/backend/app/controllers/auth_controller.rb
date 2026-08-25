# frozen_string_literal: true

# X ログインの経路です。
#
# 一般の利用者がブラウザだけで完了できる導線のみを提供します。
# 開発者向けの近道を、この経路に作りません。
class AuthController < ApplicationController
  # 認可へ送り出すときと、戻ってきたときに使う一時的な値です。
  STATE_COOKIE = :hpf_oauth_state
  VERIFIER_COOKIE = :hpf_oauth_verifier
  TEMPORARY_COOKIE_LIFETIME = 10.minutes

  # 認可画面へ送り出します。
  def start
    authorization = oauth_client.authorization

    set_temporary_cookie(STATE_COOKIE, authorization.state)
    set_temporary_cookie(VERIFIER_COOKIE, authorization.code_verifier)

    redirect_to authorization.url, allow_other_host: true
  end

  # 認可から戻ってきたところです。
  def callback
    complete_login
    redirect_to after_login_path, allow_other_host: true
  rescue InvalidStateError
    redirect_to login_failure_path('invalid_state'), allow_other_host: true
  rescue Auth::XOauthClient::UnauthorizedError, Auth::XOauthClient::InvalidResponseError
    redirect_to login_failure_path('rejected'), allow_other_host: true
  rescue Auth::XOauthClient::UnavailableError
    redirect_to login_failure_path('unavailable'), allow_other_host: true
  end

  # ログアウトします。
  def destroy
    Session.find_alive(cookies.signed[AuthenticatesUser::SESSION_COOKIE])&.revoke!
    cookies.delete(AuthenticatesUser::SESSION_COOKIE)

    redirect_to root_path_of_frontend, allow_other_host: true
  end

  private

  # 照合値が一致しない場合に投げます。
  class InvalidStateError < StandardError; end

  def complete_login
    verify_state!
    identity = exchange_code!
    user = upsert_user(identity)
    plan_updater.refresh(user)
    establish_session(user)
  end

  def verify_state!
    expected = cookies.signed[STATE_COOKIE]
    given = params[:state]

    raise InvalidStateError if expected.blank? || given.blank?
    raise InvalidStateError unless ActiveSupport::SecurityUtils.secure_compare(expected, given)
  end

  def exchange_code!
    code = params.require(:code)
    verifier = cookies.signed[VERIFIER_COOKIE]
    raise InvalidStateError if verifier.blank?

    identity = oauth_client.exchange(code: code, code_verifier: verifier)
    cookies.delete(STATE_COOKIE)
    cookies.delete(VERIFIER_COOKIE)
    identity
  end

  def upsert_user(identity)
    user = User.find_or_initialize_by(x_user_id: identity.x_user_id)
    user.display_name = identity.display_name
    user.save!
    user
  end

  def establish_session(user)
    _session, token = Session.issue(user: user)
    cookies.signed[AuthenticatesUser::SESSION_COOKIE] = session_cookie_options(token)
  end

  def session_cookie_options(token)
    {
      value: token,
      httponly: true,
      secure: AppEnvironment.production?,
      same_site: :lax,
      expires: Session::LIFETIME.from_now
    }
  end

  def set_temporary_cookie(name, value)
    cookies.signed[name] = {
      value: value,
      httponly: true,
      secure: AppEnvironment.production?,
      same_site: :lax,
      expires: TEMPORARY_COOKIE_LIFETIME.from_now
    }
  end

  def oauth_client
    @oauth_client ||= Auth::XOauthClient.new
  end

  def plan_updater
    @plan_updater ||= Auth::PlanUpdater.new
  end

  def frontend_base_url
    ENV.fetch('FRONTEND_BASE_URL')
  end

  def root_path_of_frontend
    frontend_base_url
  end

  def after_login_path
    URI.join(frontend_base_url, '/projects').to_s
  end

  def login_failure_path(reason)
    uri = URI.join(frontend_base_url, '/login')
    uri.query = URI.encode_www_form(reason: reason)
    uri.to_s
  end
end
