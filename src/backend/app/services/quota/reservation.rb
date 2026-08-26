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
    # **この持ち場の例外は、すべて `reservation/` の下に置いています。**
    #
    #   ExhaustedError            : 本日の枠を使い切っています
    #   MissingReservationError   : 予約が見つかりません
    #   NotSettleableError        : まだ確定も返還もできません
    #   ForeignRequestError       : 他人の生成リクエストです
    #   DanglingReservationError  : 決着が漏れた予約が別の日に残っています
    #   AmbiguousReservationError : 予約中の記録が複数あります

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

      # **保存点を作ってから保存します。**
      # 呼び出す側がトランザクションで包んでいると、一意性の違反で外側の
      # トランザクション全体が中断状態になり、続く問い合わせが拒まれます
      # （`PG::InFailedSqlTransaction`）。上限到達の読み替えそのものが
      # 働かなくなります。`requires_new: true` で保存点を作ると、
      # 中断は内側だけで止まります。
      def create!(user, quota_day, prompt_request)
        QuotaConsumption.transaction(requires_new: true) do
          QuotaConsumption.create!(user: user, quota_day: quota_day,
                                   **request_attributes(prompt_request))
        end
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
        raise translation_for(user, quota_day, prompt_request) || e
      end

      # 保存できなかった理由を、この持ち場の例外へ読み替えます。
      #
      # **読み替えられない理由は隠しません。** その場合は空を返し、
      # もとの例外をそのまま投げ直させます。
      def translation_for(user, quota_day, prompt_request)
        # その日の記録がすでにあるなら、並列に投入されて先を越されています。
        return exhausted(quota_day) if QuotaConsumption.find_for(user, quota_day)

        dangling_reservation(prompt_request)
      end

      # 決着が漏れた予約が、別のクォータ日に残っていないかを調べます。
      #
      # 残っていると、一意索引（予約中 × 生成リクエスト）が保存を止めます。
      # 利用者から見ると枠は残っているのに予約できないため、**理由を添えます。**
      def dangling_reservation(prompt_request)
        return nil if prompt_request.nil?

        reserved = QuotaConsumption.find_by(prompt_request_id: prompt_request.id,
                                            status: 'reserved')
        return nil if reserved.nil?

        DanglingReservationError.new(prompt_request_id: prompt_request.id,
                                     quota_day: reserved.quota_day)
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
            reclaim!(consumption, prompt_request)
          else
            raise exhausted(quota_day)
          end
        end
      end

      # 返還済みの枠を取り直します。
      #
      # 同じ生成リクエストの予約が別の日に残っていると、一意索引が止めます。
      # **索引名と鍵の値を外へ出さず、この持ち場の例外へ包み直します。**
      #
      # **ここでも保存点を作ります。** `claim!` は行に錠をかけるために
      # トランザクションを開きます。その中で一意性の違反が起きると、
      # トランザクション全体が中断状態になり、**理由を調べる問い合わせ自体が
      # 拒まれます**（`PG::InFailedSqlTransaction`）。包み直しが働きません。
      def reclaim!(consumption, prompt_request)
        QuotaConsumption.transaction(requires_new: true) do
          consumption.transition_to!('reserved', **request_attributes(prompt_request))
        end
        consumption
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
        raise dangling_reservation(prompt_request) || e
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

      # 予約中の記録を引きます。
      #
      # **2 件以上あれば失敗させます。黙って新しい方を選びません。**
      # どれを決着させるかを選び方で決めると、選び方を変えたときに結果が
      # 変わります。一意索引（予約中 × 生成リクエスト）が防いでいますが、
      # 索引を外したときに静かに間違えないようにします。
      def reserved_for(prompt_request)
        found = QuotaConsumption.where(prompt_request_id: prompt_request.id,
                                       status: 'reserved')
                                .order(quota_day: :desc)
                                .to_a
        ensure_single!(found, prompt_request)

        found.first
      end

      def ensure_single!(found, prompt_request)
        return if found.size <= 1

        raise AmbiguousReservationError,
              "予約中の記録が#{found.size}件あります: prompt_request=#{prompt_request.id}" # 開発者向け
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
