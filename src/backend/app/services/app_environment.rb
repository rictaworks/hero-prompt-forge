# frozen_string_literal: true

# 実行中の環境を判定します。
#
# 環境ごとの分岐は、必ずこのクラスを通します。環境変数を各所で直接読むと、
# 判定の条件が散らばって追えなくなるためです。
#
# 未設定・未知の値は例外にします。既定値へ寄せると、本番で開発向けの分岐が
# 有効になっていても気づけないためです。
class AppEnvironment
  KNOWN = %w[development test production].freeze

  class UnknownEnvironmentError < StandardError; end

  class << self
    # @return [String] development / test / production
    def current
      value = ENV.fetch('APP_ENV', nil) || Rails.env.to_s
      raise UnknownEnvironmentError, "APP_ENV が不正です: #{value.inspect}" unless KNOWN.include?(value)

      value
    end

    def development? = current == 'development'
    def test? = current == 'test'
    def production? = current == 'production'

    # 開発向けの近道を有効にしてよい環境かどうかを返します。
    # 本番では必ず false を返します。
    def developer_shortcuts_allowed?
      development? || test?
    end
  end
end
