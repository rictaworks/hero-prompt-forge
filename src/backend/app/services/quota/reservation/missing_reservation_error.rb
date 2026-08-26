# frozen_string_literal: true

module Quota
  class Reservation
    # 予約が見つからない場合に投げます。
    #
    # 決着できるのは予約中の記録だけです。返還済み・確定済みは履歴として
    # 残るため、生成リクエストの識別子だけで引くと、日をまたぐ再実行で
    # 前日の記録に当たります。
    class MissingReservationError < StandardError; end
  end
end
