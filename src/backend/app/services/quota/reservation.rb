# frozen_string_literal: true

module Quota
  # クォータの予約・確定・返還です（requirements.md 4.4）。
  #
  # ジョブ投入の時点で予約し、成果物を提供できたら確定、失敗したら返還します。
  # 帰属するクォータ日は**予約した時点**で決まり、生成の完了が境界を跨いでも
  # 変わりません。
  #
  #   queued              : 予約します
  #   completed           : 確定します
  #   degraded_completed  : 確定します（縮退でも成果物を提供しているためです）
  #   failed              : 返還します。当日中に作り直せます
  #   rejected            : 予約の前に決まるため、枠を使いません
  #
  # 予約は QuotaConsumption の一意制約（利用者 × クォータ日）に守られます。
  # 並列に投入されても、通るのは1件だけです。
  class Reservation
    # 本日の枠を使い切っている場合に投げます。次回のリセット時刻を添えます。
    class ExhaustedError < StandardError
      attr_reader :quota_day, :reset_at

      def initialize(quota_day:, reset_at:)
        @quota_day = quota_day
        @reset_at = reset_at
        super("本日の枠を使い切っています: #{quota_day}") # 開発者向け
      end
    end

    # 予約が見つからない場合に投げます。
    class MissingReservationError < StandardError; end

    # まだ確定も返還もできない状態で決着を求められた場合に投げます。
    class NotSettleableError < StandardError; end

    # 他人の生成リクエストへ枠を結び付けようとした場合に投げます。
    class ForeignRequestError < StandardError; end

    class << self
      # その時点のクォータ日で枠を予約します。
      # @return [QuotaConsumption]
      def reserve!(user:, prompt_request: nil, now: Time.current)
        ensure_owner!(user, prompt_request)
        quota_day = QuotaDay.of(now)
        consumption = QuotaConsumption.find_for(user, quota_day)

        return create!(user, quota_day, prompt_request) if consumption.nil?
        return reuse!(consumption, prompt_request) if reusable?(consumption, prompt_request)

        raise exhausted(quota_day)
      end

      # 生成リクエストの結果に合わせて、確定または返還します。
      # @return [QuotaConsumption]
      def settle!(prompt_request)
        consumption = QuotaConsumption.find_by(prompt_request_id: prompt_request.id)
        if consumption.nil?
          raise MissingReservationError,
                "予約がありません: prompt_request=#{prompt_request.id}" # 開発者向け
        end

        consumption.transition_to!(next_status_for(prompt_request))
        consumption
      end

      # その時点で枠が残っているかどうかを返します。
      def remaining_for?(user, now: Time.current)
        consumption = QuotaConsumption.find_for(user, QuotaDay.of(now))

        consumption.nil? || !consumption.consuming?
      end

      private

      # 他人の生成リクエストへ枠を結び付けさせません。枠は利用者に属します。
      def ensure_owner!(user, prompt_request)
        return if prompt_request.nil?
        return if prompt_request.user == user

        raise ForeignRequestError,
              "他人の生成リクエストです: prompt_request=#{prompt_request.id}" # 開発者向け
      end

      def create!(user, quota_day, prompt_request)
        QuotaConsumption.create!(user: user, quota_day: quota_day,
                                 prompt_request: prompt_request)
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        # 並列に投入され、先を越されました。上限に達したものとして扱います。
        raise exhausted(quota_day)
      end

      # 返還済みは作り直せます。同じ生成リクエストの予約は繰り返しても増やしません。
      def reusable?(consumption, prompt_request)
        return true if consumption.status == 'refunded'

        consumption.status == 'reserved' &&
          prompt_request.present? &&
          consumption.prompt_request_id == prompt_request.id
      end

      def reuse!(consumption, prompt_request)
        return consumption if consumption.status == 'reserved'

        consumption.transition_to!('reserved', prompt_request: prompt_request)
        consumption
      end

      def next_status_for(prompt_request)
        return 'confirmed' if prompt_request.delivered?
        return 'refunded' if prompt_request.status == 'failed'

        raise NotSettleableError,
              "決着していません: #{prompt_request.status}" # 開発者向け
      end

      def exhausted(quota_day)
        ExhaustedError.new(quota_day: quota_day, reset_at: QuotaDay.reset_at(quota_day))
      end
    end
  end
end
