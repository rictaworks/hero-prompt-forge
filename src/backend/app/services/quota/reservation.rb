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

        claim!(consumption, prompt_request, quota_day)
      end

      # 生成リクエストの結果に合わせて、確定または返還します。
      #
      # 決着できるのは予約中の記録だけです。返還済み・確定済みは履歴として残るため、
      # 生成リクエストの識別子だけで引くと、日をまたぐ再実行で前日の記録に当たります。
      # @return [QuotaConsumption]
      def settle!(prompt_request)
        consumption = reserved_for(prompt_request)
        if consumption.nil?
          raise MissingReservationError,
                "予約中の記録がありません: prompt_request=#{prompt_request.id}" # 開発者向け
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
                                 **request_attributes(prompt_request))
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        # その日の記録がすでにあるなら、並列に投入されて先を越されています。
        # それ以外の理由で保存できなかった場合は、上限到達として隠しません。
        raise exhausted(quota_day) if QuotaConsumption.find_for(user, quota_day)

        raise
      end

      # すでにある記録から枠を取り直します。
      #
      # **行に錠をかけてから状態を見ます。** 読むところと書くところの間に他の
      # 呼び出しが割り込むと、返還済みの枠を2つの呼び出しが同時に取れてしまいます。
      # 作り直しは行の更新であり、利用者 × クォータ日の一意制約では止まりません。
      def claim!(consumption, prompt_request, quota_day)
        consumption.with_lock do
          if same_request_reserved?(consumption, prompt_request)
            consumption
          elsif consumption.status == 'refunded'
            consumption.transition_to!('reserved', **request_attributes(prompt_request))
            consumption
          else
            raise exhausted(quota_day)
          end
        end
      end

      # 同じ生成リクエストの予約を繰り返し呼んでも増やしません。
      def same_request_reserved?(consumption, prompt_request)
        consumption.status == 'reserved' &&
          prompt_request.present? &&
          consumption.prompt_request_id == prompt_request.id
      end

      # 生成リクエストが無ければ、結び付きに触れません。触れると、返還のもとに
      # なった生成リクエストとの結び付きが空で上書きされ、履歴を追えなくなります。
      def request_attributes(prompt_request)
        return {} if prompt_request.nil?

        { prompt_request: prompt_request }
      end

      def reserved_for(prompt_request)
        QuotaConsumption.where(prompt_request_id: prompt_request.id, status: 'reserved')
                        .order(quota_day: :desc)
                        .first
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
