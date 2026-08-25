# frozen_string_literal: true

# 処理の経過を追えるようにするための記録です。
#
# どの入力で、どの分岐を通り、何が返ったかを1行ずつ残します。
# 例外は握りつぶさず、記録したうえで呼び出し元へ投げ直します。
module Trace
  module_function

  # @param name [String] 処理の名前
  # @param context [Hash] 追跡に必要な値。秘匿値を入れません
  def step(name, **context)
    Rails.logger.info("[trace] #{name} #{format_context(context)}")
    result = yield
    Rails.logger.info("[trace] #{name} 完了 #{format_context(context)}")
    result
  rescue StandardError => e
    Rails.logger.error("[trace] #{name} 失敗 #{format_context(context)} error=#{e.class}: #{e.message}")
    raise
  end

  def format_context(context)
    context.map { |k, v| "#{k}=#{v.inspect}" }.join(' ')
  end
end
