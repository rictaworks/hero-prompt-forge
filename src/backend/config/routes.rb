# frozen_string_literal: true

Rails.application.routes.draw do
  # X ログインです。一般の利用者がブラウザだけで完了できる導線のみを提供します。
  get  'auth/start',    to: 'auth#start'
  get  'auth/callback', to: 'auth#callback'
  delete 'auth/session', to: 'auth#destroy'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # 死活監視です（requirements.md 7.3）。**データベースへ到達できることまで
  # 含めて答えます。** 認証を求めません。外形監視サービスが呼びます。
  get 'health', to: 'health#show'

  # 開発者用の管理画面です（requirements.md 4.3、5.2）。BASIC 認証が掛かります。
  # **一般の利用者の画面（Next.js）とは入口を分けます。**
  namespace :admin do
    root to: 'dashboard#show'
  end

  # Rails の既定の死活確認です。**アプリが起動しているかどうかだけを見ます。**
  # データベースへ到達できるかどうかは `/health` が答えます。
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
