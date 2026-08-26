# frozen_string_literal: true

module Quota
  class Reservation
    # まだ確定も返還もできない状態で決着を求められた場合に投げます。
    class NotSettleableError < StandardError; end
  end
end
