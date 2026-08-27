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

  # 一般の利用者の API です（SPEC/api/README.md）。**基底パスは `/api/v1` です。**
  # 版を付けて、画面と足並みを揃えて変えられるようにします。
  namespace :api do
    namespace :v1 do
      # いまログインしている利用者です。**上部バーが使います。**
      # **プラン値の判定を求めません。** `pending` の方も自分の状態を見られます。
      resource :session, only: %i[show], controller: 'session'

      # プロジェクトです（requirements.md 4.1）。
      # **消す経路を作りません。** 生成履歴が結び付いています。
      resources :projects, only: %i[index create update]

      # プリセットです（requirements.md 4.5）。
      resources :presets, only: %i[index show create update]

      # 生成リクエストです（requirements.md 4.1、12.1）。
      # **作成と取り出しだけです。** 途中で書き換える経路を作りません。
      # `index` は生成履歴です。
      resources :prompt_requests, only: %i[index create show]

      # 評価メモです（requirements.md 4.6）。**案 1 つにつき 1 件です。**
      resources :prompt_outputs, only: [] do
        resource :evaluation_note, only: %i[show create update]
      end
    end
  end

  # 開発者用の管理画面です（requirements.md 4.3、5.2）。BASIC 認証が掛かります。
  # **一般の利用者の画面（Next.js）とは入口を分けます。**
  namespace :admin do
    root to: 'dashboard#show'

    # 規則辞書の編集です（issue #65）。
    # **公開済みの版は書き換えません。** 内容を変える場合は新しい版を作ります。
    resources :rule_dictionaries, only: %i[index show new create], path: 'rule-dictionaries' do
      member { post :publish }
    end

    # 利用者とプラン値の管理です（issue #66）と、クォータの手動リセットです（issue #67）。
    resources :users, only: %i[index show] do
      member do
        post :recheck
        post :reset_quota, path: 'reset-quota'
      end
    end

    # 利用状況の集計です（issue #68）。**仕様が定める軸だけを出します。**
    resource :metrics, only: %i[show], controller: 'metrics'
  end

  # Rails の既定の死活確認です。**アプリが起動しているかどうかだけを見ます。**
  # データベースへ到達できるかどうかは `/health` が答えます。
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
