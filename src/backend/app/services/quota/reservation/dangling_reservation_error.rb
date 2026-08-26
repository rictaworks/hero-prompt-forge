# frozen_string_literal: true

module Quota
  class Reservation
    # 決着が漏れた予約が、別のクォータ日に残っている場合に投げます。
    #
    # **データベースの一意索引が止めた事実を、この持ち場の例外へ包み直します。**
    # 包まずに素通しすると、呼び出す側（issue #55 の API）が自前の例外だけを
    # 捕まえる作りのときに 500 になります。索引名と鍵の値も外へ漏れます。
    #
    # 利用者から見ると、枠は残っているのに予約できない状態です。**どのクォータ日に
    # 残っているかを添えます。** 添えないと、運用で決着の漏れを追えません。
    class DanglingReservationError < StandardError
      # 開発者へ知らせる文面です。利用者へ見せる文言は上位の層が組み立てます。
      MESSAGE = '予約が別のクォータ日（%<quota_day>s）に残っています: prompt_request=%<prompt_request_id>s' # 開発者向け

      attr_reader :prompt_request_id, :quota_day

      def initialize(prompt_request_id:, quota_day:)
        @prompt_request_id = prompt_request_id
        @quota_day = quota_day
        super(format(MESSAGE, quota_day: quota_day, prompt_request_id: prompt_request_id))
      end
    end
  end
end
