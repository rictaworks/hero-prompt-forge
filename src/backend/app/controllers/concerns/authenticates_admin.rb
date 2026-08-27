# frozen_string_literal: true

# 開発者用の管理画面の認証です（requirements.md 5.2）。
#
# **BASIC 認証です。** 管理画面は開発者だけが使います。利用者の X ログインとは
# 別の仕組みにします。混ぜると、利用者の権限で管理の操作へ届く経路ができます。
#
# **資格情報の読み出しと照合は `Admin::Credentials` が持ちます。**
# ここには「照合を要求すること」と「通った名前を控えること」だけを残します。
# 照合の結果と実施者を別々に扱うと、**通らなかった名前を実施者として控える
# 書き換えが、どのテストにも当たらないまま通ります**（issue #177 の M12）。
module AuthenticatesAdmin
  extend ActiveSupport::Concern

  # 資格情報の置き場と、設定されていない場合の失敗は `Admin::Credentials` が持ちます。
  # **ここでは呼び名だけを引き継ぎます。**
  MissingCredentialsError = Admin::Credentials::MissingCredentialsError
  USER_NAME_KEY = Admin::Credentials::USER_NAME_KEY
  PASSWORD_KEY = Admin::Credentials::PASSWORD_KEY

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
      @admin_actor = Admin::Credentials.from_env.actor_for(name, password)
      @admin_actor.present?
    end
  end
end
