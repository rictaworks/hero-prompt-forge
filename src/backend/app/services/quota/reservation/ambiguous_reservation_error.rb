# frozen_string_literal: true

module Quota
  class Reservation
    # 予約中の記録が複数見つかった場合に投げます。
    #
    # **黙って新しい方を選びません。** どれを決着させるかは、選び方の違いで
    # 結果が変わります。データベースの一意索引（予約中 × 生成リクエスト）が
    # 防いでいますが、索引を外したり作り忘れたりしたときに、静かに間違えない
    # ようにします。
    class AmbiguousReservationError < StandardError; end
  end
end
