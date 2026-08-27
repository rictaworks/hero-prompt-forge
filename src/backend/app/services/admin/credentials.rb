# frozen_string_literal: true

module Admin
  # 開発者用の管理画面の資格情報です（requirements.md 5.2）。
  #
  # **資格情報は環境変数から読みます。** ソースへ書きません。
  # **未設定なら、その場で失敗させます。** 空の資格情報で通すと、管理画面が
  # 誰でも開ける状態になります。既定値へ寄せません。
  #
  # **照合の結果として「実施者」を返します。** 通らなかった名前は返しません。
  # 記録の実施者は、実際に管理の操作を行えた人でなければ意味がありません。
  # 通らなかった名前を控えると、**誰でも好きな名前を監査の記録へ残せます**
  # （issue #177 の M12）。呼び出し側で「通ったかどうか」を見て控える形にすると、
  # その分岐がどのテストにも当たらないまま残ります。**ここで一体にします。**
  class Credentials
    # 資格情報が設定されていない場合に投げます。
    class MissingCredentialsError < StandardError; end

    USER_NAME_KEY = 'ADMIN_BASIC_AUTH_USER'
    PASSWORD_KEY = 'ADMIN_BASIC_AUTH_PASSWORD'

    # 環境変数から組み立てます。**未設定なら、その場で失敗させます。**
    def self.from_env
      name = ENV.fetch(USER_NAME_KEY, nil)
      password = ENV.fetch(PASSWORD_KEY, nil)
      return new(name: name, password: password) if name.present? && password.present?

      raise MissingCredentialsError,
            "管理画面の資格情報が設定されていません: #{USER_NAME_KEY} / #{PASSWORD_KEY}" # 開発者向け
    end

    def initialize(name:, password:)
      @name = name
      @password = password
    end

    # **通った名前だけを返します。** 通らなければ `nil` を返します。
    def actor_for(candidate_name, candidate_password)
      return nil unless matches?(candidate_name, candidate_password)

      candidate_name.to_s
    end

    private

    attr_reader :name, :password

    # **比較は時間の差が出ない方法で行います。** 素の `==` は、先頭から何文字
    # 一致したかで時間が変わります。文字ごとに試して資格情報を割り出せます。
    #
    # **`&` を使います。`&&` にすると、利用者名が違った時点で合言葉の照合を
    # 省きます。** 省いた分だけ応答が速くなり、どちらが違うかが漏れます。
    def matches?(candidate_name, candidate_password)
      ActiveSupport::SecurityUtils.secure_compare(candidate_name.to_s, name) &
        ActiveSupport::SecurityUtils.secure_compare(candidate_password.to_s, password)
    end
  end
end
