# frozen_string_literal: true

module Quota
  # クォータ日です。
  #
  # リセット時刻は **JST 03:00** です。03:00 を境界とする「クォータ日」で
  # 消費を管理します（requirements.md 4.4）。
  #
  #   2026-08-25 02:59 JST → クォータ日 2026-08-24
  #   2026-08-25 03:00 JST → クォータ日 2026-08-25
  #
  # 時刻の扱いを1か所へ集約します。各所で日付を計算すると、境界の解釈が
  # ずれて「日付が変わったのに枠が戻らない」といった不具合になります。
  #
  # **時刻を渡す入口と、日付を渡す入口を取り違えると答えが1日ずれます。**
  # 取り違えは握りつぶさず、その場で失敗させます。
  class QuotaDay
    ZONE = 'Asia/Tokyo'
    RESET_HOUR = 3

    class << self
      # その時刻が属するクォータ日を返します。
      # @param time [Time] 時刻です。日付を渡すと失敗します
      # @return [Date]
      def of(time = Time.current)
        ensure_time!(time)

        local = time.in_time_zone(ZONE)
        local.hour < RESET_HOUR ? local.to_date - 1 : local.to_date
      end

      # そのクォータ日が始まる時刻を返します。
      # @param quota_day [Date] クォータ日です。時刻を渡すと失敗します
      # @return [ActiveSupport::TimeWithZone]
      def start_at(quota_day)
        ensure_date!(quota_day)

        Time.use_zone(ZONE) do
          Time.zone.local(quota_day.year, quota_day.month, quota_day.day, RESET_HOUR)
        end
      end

      # そのクォータ日が終わる時刻（＝次のリセット時刻）を返します。
      # @param quota_day [Date] クォータ日です。時刻を渡すと失敗します
      # @return [ActiveSupport::TimeWithZone]
      def reset_at(quota_day)
        start_at(quota_day) + 1.day
      end

      # 次のリセットまでの秒数を返します。
      # @param time [Time] 時刻です。日付を渡すと失敗します
      # @return [Integer]
      def seconds_until_reset(time = Time.current)
        (reset_at(of(time)) - time).ceil
      end

      private

      # 時刻を受け取る入口です。日付（Date）は時刻を持たないため拒否します。
      def ensure_time!(value)
        return if value.respond_to?(:hour) && value.respond_to?(:in_time_zone)

        raise ArgumentError, "時刻を渡してください: #{value.inspect}" # 開発者向け
      end

      # 日付を受け取る入口です。時刻（Time / DateTime）を渡すと、時刻の部分が
      # 捨てられて答えが1日ずれるため拒否します。
      def ensure_date!(value)
        return if value.instance_of?(Date)

        raise ArgumentError, "日付を渡してください: #{value.inspect}" # 開発者向け
      end
    end
  end
end
