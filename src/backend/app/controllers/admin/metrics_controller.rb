# frozen_string_literal: true

module Admin
  # 利用状況の集計です（requirements.md 7.1、issue #68）。
  #
  # **仕様が定める軸だけを出します。** 定義に無い指標を増やしません。
  #
  # **個人を特定できる形で出しません。** 利用者ごとの件数は、名前も識別子も
  # 添えずに**分布**として出します。「どなたが何回使ったか」を、この画面から
  # 読み取れないようにします。
  class MetricsController < ApplicationController
    def show
      @summary = Metrics::UsageSummary.new.call
    end
  end
end
