# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { 'cache-control' => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # **`assume_ssl` を有効にしません。**
  # 有効にすると、Rails はすべての要求を TLS の上のものとして扱います。
  # その結果、**平文の要求でも転送が起きず、`force_ssl` が働きません**
  # （PR #150 のレビューで実測されました）。
  #
  # 配置先（Railway）は TLS を終端し、`X-Forwarded-Proto` を付けて渡します。
  # Rails はその印を見て、TLS の上かどうかを判断します。**印がある要求は
  # 転送されず、印の無い平文の要求だけが転送されます。**

  # **すべての通信を TLS の上でだけ行います。**
  # 管理画面は BASIC 認証です。BASIC 認証の資格情報は、TLS が無ければ
  # そのまま読み取れる形で流れます（requirements.md 5.2）。
  config.assume_ssl = false
  config.force_ssl = true

  # 死活監視だけは、平文の要求でも答えます。外形監視サービスが
  # 追従できない場合に、稼働しているのに落ちていると判定されるためです。
  config.ssl_options = {
    redirect: { exclude: ->(request) { ['/up', '/health'].include?(request.path) } }
  }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [:request_id]
  config.logger   = ActiveSupport::TaggedLogging.logger($stdout)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info')

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = '/up'

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: 'example.com' }

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via bin/rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
