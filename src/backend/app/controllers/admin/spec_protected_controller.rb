# frozen_string_literal: true

module Admin
  # 管理画面の守りを検証するための経路です。
  #
  # テストからのみ経路を割り当てます。本番の経路表には現れません。
  #
  # **書き込みの経路を持ちます。** 管理画面の CSRF 対策が実際に働いているかは、
  # 読み取りの経路では確かめられません。規則辞書の編集（issue #65）などが
  # 書き込みを足す前に、守りが働いていることを固定します。
  class SpecProtectedController < ApplicationController
    def show
      render plain: 'ok'
    end

    def update
      render plain: 'updated'
    end
  end
end
