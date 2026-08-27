# frozen_string_literal: true

require 'rails_helper'

# 開発者用の管理画面の認証を、実際の要求として確かめます（requirements.md 5.2）。
RSpec.describe '管理画面' do # rubocop:disable RSpec/DescribeClass
  let(:name) { 'admin-for-spec' }
  let(:password) { 'password-for-spec' }

  def with_credentials(user: name, secret: password)
    ActionController::HttpAuthentication::Basic.encode_credentials(user, secret)
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with(AuthenticatesAdmin::USER_NAME_KEY, nil).and_return(name)
    allow(ENV).to receive(:fetch).with(AuthenticatesAdmin::PASSWORD_KEY, nil).and_return(password)
  end

  describe '認証がないとき' do
    it '401 を返します' do
      get '/admin'

      expect(response).to have_http_status(:unauthorized)
    end

    # **中身を出しません。** 認証を通る前に画面の内容が見えてはいけません。
    it '画面の内容を返しません' do
      get '/admin'

      expect(response.body).not_to include('管理画面')
    end
  end

  describe '資格情報が違うとき' do
    it '利用者名が違えば 401 を返します' do
      get '/admin', headers: { 'HTTP_AUTHORIZATION' => with_credentials(user: 'stranger') }

      expect(response).to have_http_status(:unauthorized)
    end

    it '合言葉が違えば 401 を返します' do
      get '/admin', headers: { 'HTTP_AUTHORIZATION' => with_credentials(secret: 'wrong') }

      expect(response).to have_http_status(:unauthorized)
    end

    it '空の資格情報では通しません' do
      get '/admin', headers: { 'HTTP_AUTHORIZATION' => with_credentials(user: '', secret: '') }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe '資格情報が正しいとき' do
    it '200 を返します' do
      get '/admin', headers: { 'HTTP_AUTHORIZATION' => with_credentials }

      expect(response).to have_http_status(:ok)
    end

    it '画面を返します' do
      get '/admin', headers: { 'HTTP_AUTHORIZATION' => with_credentials }

      expect(response.body).to include('管理画面')
    end

    # **検索の対象にしません。** 管理画面は開発者だけが使います。
    it '検索避けを入れます' do
      get '/admin', headers: { 'HTTP_AUTHORIZATION' => with_credentials }

      expect(response.body).to include('noindex')
    end
  end

  # **資格情報が未設定なら、その場で失敗させます。**
  # 空文字と照合して通すと、設定し忘れた環境で誰でも開ける状態になります。
  describe '資格情報が設定されていないとき' do
    before do
      allow(ENV).to receive(:fetch).with(AuthenticatesAdmin::USER_NAME_KEY, nil).and_return(nil)
    end

    it '失敗させます' do
      expect { get '/admin', headers: { 'HTTP_AUTHORIZATION' => with_credentials } }
        .to raise_error(AuthenticatesAdmin::MissingCredentialsError)
    end

    it '空文字でも失敗させます' do
      allow(ENV).to receive(:fetch).with(AuthenticatesAdmin::USER_NAME_KEY, nil).and_return('')

      expect { get '/admin', headers: { 'HTTP_AUTHORIZATION' => with_credentials } }
        .to raise_error(AuthenticatesAdmin::MissingCredentialsError)
    end
  end

  # **CSRF 対策が実際に働いていることを確かめます**（PR #150 のレビューより）。
  #
  # API モードではセッションの仕組みが外れており、`protect_from_forgery` を
  # 書いても働きません。**書いたつもりで守られていない**状態になります。
  # 読み取りの経路では確かめられませんので、書き込みの経路で確かめます。
  describe '書き込みの守り' do
    before do
      Rails.application.routes.draw do
        namespace :admin do
          get '/spec/protected', to: 'spec_protected#show'
          post '/spec/protected', to: 'spec_protected#update'
        end
      end
      ActionController::Base.allow_forgery_protection = true
    end

    after do
      ActionController::Base.allow_forgery_protection = false
      Rails.application.reload_routes!
    end

    it '認証があっても、印の無い書き込みは通しません' do
      post '/admin/spec/protected', headers: { 'HTTP_AUTHORIZATION' => with_credentials }

      expect(response).not_to have_http_status(:ok)
    end

    it '印が無いことを理由に止めます' do
      post '/admin/spec/protected', headers: { 'HTTP_AUTHORIZATION' => with_credentials }

      expect(response.body).to include('InvalidAuthenticityToken')
    end

    it '読み取りは通ります' do
      get '/admin/spec/protected', headers: { 'HTTP_AUTHORIZATION' => with_credentials }

      expect(response).to have_http_status(:ok)
    end

    it '認証が無ければ、書き込みも通しません' do
      post '/admin/spec/protected'

      expect(response).to have_http_status(:unauthorized)
    end

    # **守りが働く前提（セッション）がそろっていることを確かめます。**
    it '管理画面ではセッションを使えます' do
      get '/admin/spec/protected', headers: { 'HTTP_AUTHORIZATION' => with_credentials }

      expect(request.session).to be_a(ActionDispatch::Request::Session)
    end
  end

  # **お知らせ（flash）の仕組みが組み込まれていることを確かめます。**
  #
  # API モードでは既定で外れています。**組み込まないまま `flash` を書くと、
  # 画面を組み立てる段で必ず落ちます。** リクエストテストでは表に出ません
  # （テストの側が `flash` を参照して読み込むためです）。
  # **仕組みそのものを見ます**（PR #175 の整備で実測されました）。
  describe 'お知らせの仕組み' do
    it '組み込まれています' do
      names = Rails.application.config.middleware.map { |item| item.name.to_s }

      expect(names).to include('ActionDispatch::Flash')
    end
  end

  # **利用者の X ログインでは、管理画面へ届きません。**
  describe '利用者の認証との切り分け' do
    it '利用者のセッションでは通しません' do
      user = User.create!(x_user_id: '5555555555', display_name: 'あか', plan: 'active')
      Session.issue(user: user)

      get '/admin'

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
