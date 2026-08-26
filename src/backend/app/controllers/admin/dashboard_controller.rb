# frozen_string_literal: true

module Admin
  # 管理画面の入口です。
  #
  # **BASIC 認証が掛かっていることを確かめるための、最小の画面です。**
  # 規則辞書の編集（issue #65）・利用者とプラン値の管理（issue #66）・
  # クォータの手動リセット（issue #67）・利用状況の集計（issue #68）は、
  # それぞれの issue で足します。**まだ無い画面への導線を出しません。**
  class DashboardController < ApplicationController
    def show; end
  end
end
