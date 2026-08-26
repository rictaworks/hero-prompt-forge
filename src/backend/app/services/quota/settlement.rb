# frozen_string_literal: true

module Quota
  # クォータの決着の引き当てです（requirements.md 4.4）。
  #
  # **決着できるのは予約中の記録だけです。** 返還済み・確定済みは履歴として
  # 残るため、生成リクエストの識別子だけで引くと、日をまたぐ再実行で前日の
  # 記録に当たります。
  class Settlement
    MissingReservationError = Reservation::MissingReservationError
    AmbiguousReservationError = Reservation::AmbiguousReservationError
    NotSettleableError = Reservation::NotSettleableError

    class << self
      # 予約中の記録を引きます。
      #
      # **2 件以上あれば失敗させます。黙って新しい方を選びません。**
      # どれを決着させるかを選び方で決めると、選び方を変えたときに結果が
      # 変わります。一意索引（予約中 × 生成リクエスト）が防いでいますが、
      # 索引を外したときに静かに間違えないようにします。
      # @return [QuotaConsumption]
      def reserved_for!(prompt_request)
        found = QuotaConsumption.where(prompt_request_id: prompt_request.id, status: 'reserved')
                                .order(quota_day: :desc)
                                .to_a
        ensure_single!(found, prompt_request)
        ensure_present!(found, prompt_request)

        found.first
      end

      # 生成リクエストの結果に対応する、次の状態です。
      def next_status_for(prompt_request)
        return 'confirmed' if prompt_request.delivered?
        return 'refunded' if prompt_request.status == 'failed'

        raise NotSettleableError, "決着していません: #{prompt_request.status}" # 開発者向け
      end

      private

      def ensure_single!(found, prompt_request)
        return if found.size <= 1

        raise AmbiguousReservationError,
              "予約中の記録が#{found.size}件あります: prompt_request=#{prompt_request.id}" # 開発者向け
      end

      def ensure_present!(found, prompt_request)
        return if found.any?

        raise MissingReservationError,
              "予約中の記録がありません: prompt_request=#{prompt_request.id}" # 開発者向け
      end
    end
  end
end
