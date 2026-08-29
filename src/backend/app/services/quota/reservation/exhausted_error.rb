# frozen_string_literal: true

module Quota
  class Reservation
    # 本日の枠を使い切っている場合に投げます。
    #
    # **次回のリセット時刻を必ず添えます。** requirements.md 4.4 は
    # 「上限到達を明示し、次回リセット時刻（JST 03:00）を必ず提示する。
    # 曖昧なエラーを返さない」と定めています。
    #
    # **使い切った枠の状態（`status`）も添えます**（issue #183）。
    # 上限到達は「予約中（`reserved`、まだ結果がありません）」と
    # 「確定済み（`confirmed`、すでに完了しています）」の両方で起こります。
    # 状態を区別せずに画面へ渡すと、まだ無い結果を「見る」導線を
    # 出しかねません。
    #
    # **`prompt_request_id` は、確定済みのときだけ添えます。** 予約中は
    # まだ見せられる結果が無いためです。
    class ExhaustedError < StandardError
      attr_reader :quota_day, :reset_at, :status, :prompt_request_id

      def initialize(quota_day:, reset_at:, status:, prompt_request_id: nil)
        @quota_day = quota_day
        @reset_at = reset_at
        @status = status
        @prompt_request_id = prompt_request_id
        super("本日の枠を使い切っています: #{quota_day}") # 開発者向け
      end
    end
  end
end
