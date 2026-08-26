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
