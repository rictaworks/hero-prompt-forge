# frozen_string_literal: true

# API が返す失敗の形です。
#
# すべての失敗でこの形を使います。曖昧なエラーを返さず、
# 利用者に見せる文言と、次に行う操作を必ず含めます。
#
# 決まりは SPEC/api/README.md にあります。
class ApiError < StandardError
  attr_reader :code, :status, :next_action, :details

  # @param code [String] 機械が判定するための識別子
  # @param message [String] 利用者に見せる文言
  # @param next_action [String] 次に行う操作
  # @param status [Integer] HTTP の状態コード
  # @param details [Hash] 補足。個人情報・秘匿値を入れません
  def initialize(code:, message:, next_action:, status:, details: {})
    raise ArgumentError, 'code を空にできません' if code.to_s.empty?
    raise ArgumentError, 'message を空にできません' if message.to_s.empty?
    raise ArgumentError, 'next_action を空にできません' if next_action.to_s.empty?

    @code = code
    @status = status
    @next_action = next_action
    @details = details
    super(message)
  end

  def to_body
    {
      error: {
        code: code,
        message: message,
        next_action: next_action,
        details: details
      }
    }
  end
end
