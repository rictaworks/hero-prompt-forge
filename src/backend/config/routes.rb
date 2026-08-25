# frozen_string_literal: true

Rails.application.routes.draw do
  # X ログインです。一般の利用者がブラウザだけで完了できる導線のみを提供します。
  get  'auth/start',    to: 'auth#start'
  get  'auth/callback', to: 'auth#callback'
  delete 'auth/session', to: 'auth#destroy'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
