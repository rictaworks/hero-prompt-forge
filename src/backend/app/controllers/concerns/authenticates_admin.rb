# frozen_string_literal: true

# 開発者用の管理画面の認証です（requirements.md 5.2）。
#
# **BASIC 認証です。** 管理画面は開発者だけが使います。利用者の X ログインとは
# 別の仕組みにします。混ぜると、利用者の権限で管理の操作へ届く経路ができます。
#
# **資格情報は環境変数から読みます。** ソースへ書きません（requirements.md 5.2）。
# **未設定なら、その場で失敗させます。** 空の資格情報で通すと、管理画面が
# 誰でも開ける状態になります。既定値へ寄せません。
#
# **比較は時間の差が出ない方法で行います。** 素の `==` は、先頭から何文字
# 一致したかで時間が変わります。文字ごとに試して資格情報を割り出せます。
module AuthenticatesAdmin
  extend ActiveSupport::Concern

  # 資格情報が設定されていない場合に投げます。
  class MissingCredentialsError < StandardError; end

  USER_NAME_KEY = 'ADMIN_BASIC_AUTH_USER'
  PASSWORD_KEY = 'ADMIN_BASIC_AUTH_PASSWORD'

  # ブラウザの認証の窓に出る名前です。**利用者には見えません。**
  # 開発者だけが見るため、画面の文言とは別に持ちます。
  REALM = 'hero-prompt-forge admin' # 開発者向け

  included do
    before_action :authenticate_admin!
  end

  private

  # **通った利用者名です。** 記録の「実施者」に使います（issue #66、#67）。
  # **合言葉は残しません。**
  attr_reader :admin_actor

  def authenticate_admin!
    authenticate_or_request_with_http_basic(REALM) do |name, password|
      matched = matches?(name, password)
      @admin_actor = name if matched
      matched
    end
  end

  def matches?(name, password)
    expected_name, expected_password = credentials

    ActiveSupport::SecurityUtils.secure_compare(name.to_s, expected_name) &
      ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected_password)
  end

  # **未設定なら失敗させます。** 空文字と照合して通すと、資格情報を
  # 設定し忘れた環境で、管理画面が誰でも開ける状態になります。
  def credentials
    name = ENV.fetch(USER_NAME_KEY, nil)
    password = ENV.fetch(PASSWORD_KEY, nil)
    return [name, password] if name.present? && password.present?

    raise MissingCredentialsError,
          "管理画面の資格情報が設定されていません: #{USER_NAME_KEY} / #{PASSWORD_KEY}" # 開発者向け
  end
end
