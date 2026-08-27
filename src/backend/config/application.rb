# frozen_string_literal: true

require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_mailbox/engine'
require 'action_text/engine'
require 'action_view/railtie'
require 'action_cable/engine'
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Backend
  # 管理画面のセッションの鍵です。利用者向けのクッキーと名前を分けます。
  ADMIN_SESSION_KEY = '_hpf_admin_session'

  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # 日本語版のみを提供します。他の言語を追加しません。
    config.i18n.default_locale = :ja
    config.i18n.available_locales = [:ja]
    # 文言が見つからない場合は例外にします。既定値へ寄せると、
    # 未翻訳のまま英語の識別子が画面へ出ても気づけないためです。
    config.i18n.raise_on_missing_translations = true

    # API モードでは、クッキーを扱う仕組みが既定で外れています。
    # ログイン状態の受け渡しに署名付きクッキーを使うため、明示的に組み込みます。
    config.middleware.use ActionDispatch::Cookies

    # **管理画面の CSRF 対策には、セッションが要ります。**
    # API モードではセッションの仕組みも外れており、`protect_from_forgery` を
    # 書いても働きません（`protect_against_forgery?` が偽になるためです）。
    # 書いたつもりで守られていない状態になりますので、明示的に組み込みます。
    #
    # **利用者向けの API はセッションを使いません。** ログイン状態は署名付き
    # クッキーで受け渡します。このセッションは管理画面のためだけに使います。
    config.session_store :cookie_store, key: ADMIN_SESSION_KEY, same_site: :lax, httponly: true
    config.middleware.use ActionDispatch::Session::CookieStore,
                          key: ADMIN_SESSION_KEY, same_site: :lax, httponly: true

    # **管理画面のお知らせ（flash）にも、専用の仕組みが要ります**（issue #66、#67）。
    #
    # API モードでは、この仕組みも既定で外れています。**組み込まないまま
    # `flash` を書くと、画面を組み立てる段で必ず落ちます**（`undefined method
    # 'flash'`）。**リクエストテストでは表に出ません。** テストの側が `flash` を
    # 参照して読み込むため、テストの中でだけ動きます
    # （PR #175 の整備で実測されました）。
    #
    # **利用者向けの API は使いません。** 管理画面のためだけに組み込みます。
    config.middleware.use ActionDispatch::Flash

    # 時刻は JST です。
    config.time_zone = 'Asia/Tokyo'
    config.active_record.default_timezone = :utc

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
  end
end
