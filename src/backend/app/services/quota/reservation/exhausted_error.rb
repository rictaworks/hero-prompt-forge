# frozen_string_literal: true

module Quota
  class Reservation
    # 本日の枠を使い切っている場合に投げます。
    #
    # **次回のリセット時刻を必ず添えます。** requirements.md 4.4 は
    # 「上限到達を明示し、次回リセット時刻（JST 03:00）を必ず提示する。
    # 曖昧なエラーを返さない」と定めています。
    class ExhaustedError < StandardError
      attr_reader :quota_day, :reset_at

      def initialize(quota_day:, reset_at:)
        @quota_day = quota_day
        @reset_at = reset_at
        super("本日の枠を使い切っています: #{quota_day}") # 開発者向け
      end
    end
  end
end
