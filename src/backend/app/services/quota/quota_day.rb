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
  class QuotaDay
    ZONE = 'Asia/Tokyo'
    RESET_HOUR = 3

    class << self
      # その時刻が属するクォータ日を返します。
      # @return [Date]
      def of(time = Time.current)
        local = time.in_time_zone(ZONE)
        local.hour < RESET_HOUR ? local.to_date - 1 : local.to_date
      end

      # そのクォータ日が終わる時刻（＝次のリセット時刻）を返します。
      # @return [ActiveSupport::TimeWithZone]
      def reset_at(quota_day)
        Time.use_zone(ZONE) do
          Time.zone.local(quota_day.year, quota_day.month, quota_day.day, RESET_HOUR) + 1.day
        end
      end

      # 次のリセットまでの秒数を返します。
      def seconds_until_reset(time = Time.current)
        (reset_at(of(time)) - time).ceil
      end

      # そのクォータ日が始まる時刻を返します。
      # @return [ActiveSupport::TimeWithZone]
      def start_at(quota_day)
        Time.use_zone(ZONE) do
          Time.zone.local(quota_day.year, quota_day.month, quota_day.day, RESET_HOUR)
        end
      end
    end
  end
end
