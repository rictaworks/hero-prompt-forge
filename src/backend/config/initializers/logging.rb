# frozen_string_literal: true

# 追跡できるログの設定です。
#
# - 1リクエストにつき1つの識別子を付け、関係するすべての行に載せます
# - 例外を握りつぶさず、必ず記録します
# - 秘匿値をログへ出しません
Rails.application.configure do
  config.log_tags = [:request_id]
  config.log_level = ENV.fetch('LOG_LEVEL', 'info').to_sym

  # 記録から除外する項目です。増やす場合はここへ追記します。
  config.filter_parameters += %i[
    password
    secret
    token
    api_key
    authorization
    code_verifier
  ]
end
