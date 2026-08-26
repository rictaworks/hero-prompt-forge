# frozen_string_literal: true

module Quota
  class Reservation
    # 他人の生成リクエストへ枠を結び付けようとした場合に投げます。
    # 枠は利用者に属します。
    class ForeignRequestError < StandardError; end
  end
end
