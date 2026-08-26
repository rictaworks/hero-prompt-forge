# frozen_string_literal: true

module Admin
  # 開発者用の管理画面の土台です（requirements.md 4.3、5.2）。
  #
  # **利用者向けの `ApplicationController`（`ActionController::API`）とは別です。**
  # 管理画面は画面を返しますので、画面を組み立てられる土台を継承します。
  # 利用者向けの API は画面を返しませんので、API 用の土台のままにします。
  #
  # **管理画面のすべての画面は、この土台を継承します。** 継承を通すことで、
  # BASIC 認証の掛け忘れが起きません。画面ごとに認証を書くと、1 つ書き忘れた
  # だけで、その画面から管理の操作へ届きます。
  #
  # **一般の利用者の画面（Next.js）とは、入口そのものを分けます。**
  # 管理の導線を一般の画面へ出しません（requirements.md 4.3、CLAUDE.md）。
  class ApplicationController < ActionController::Base
    include AuthenticatesAdmin

    # 管理画面は同一の生成元からのみ操作します。
    protect_from_forgery with: :exception

    layout 'admin'
  end
end
