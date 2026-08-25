# frozen_string_literal: true

# 要求としてのテストで、署名付きクッキーを組み立てる補助です。
#
# 要求のテストではブラウザと同じ形でクッキーを渡します。署名は Rails が
# 検証するため、テスト側でも同じ方式で署名した値を渡します。
module SessionCookie
  def sign_session_cookie(token)
    request = ActionDispatch::Request.new(Rails.application.env_config.deep_dup)
    jar = ActionDispatch::Cookies::CookieJar.build(request, {})
    jar.signed[AuthenticatesUser::SESSION_COOKIE] = token
    jar[AuthenticatesUser::SESSION_COOKIE]
  end

  # 利用者としてログインした状態を作ります。
  def login_as(user)
    _session, token = Session.issue(user: user)
    cookies[AuthenticatesUser::SESSION_COOKIE] = sign_session_cookie(token)
    token
  end
end

RSpec.configure do |config|
  config.include SessionCookie, type: :request
end
