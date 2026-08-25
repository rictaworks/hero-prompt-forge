# frozen_string_literal: true

require 'rails_helper'

# 認証の振る舞いを、実際の要求として確かめます。
RSpec.describe '認証' do # rubocop:disable RSpec/DescribeClass
  let!(:user) { User.create!(x_user_id: '1234567890', display_name: 'あお', plan: 'active') }

  before do
    # 検証用の経路を用意します。本番の経路には現れません。
    Rails.application.routes.draw do
      get '/spec/protected', to: 'spec_protected#show'
      get '/spec/authorized', to: 'spec_protected#authorized'
    end
  end

  after { Rails.application.reload_routes! }

  describe '未認証の場合' do
    it '401 を返します' do
      get '/spec/protected'

      expect(response).to have_http_status(:unauthorized)
    end

    it '次に行う操作を返します' do
      get '/spec/protected'

      expect(response.parsed_body.dig('error', 'next_action')).to be_present
    end

    it '契約どおりの形で返します' do
      get '/spec/protected'

      expect(response.parsed_body['error'].keys)
        .to contain_exactly('code', 'message', 'next_action', 'details')
    end
  end

  describe 'セッションがある場合' do
    it '利用者を特定します' do
      login_as(user)

      get '/spec/protected'

      expect(response.parsed_body['x_user_id']).to eq('1234567890')
    end

    it '取り消したセッションでは通しません' do
      login_as(user)
      Session.last.revoke!

      get '/spec/protected'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'プラン値' do
    it '有効でない場合は 403 を返します' do
      user.update!(plan: 'pending')
      login_as(user)

      get '/spec/authorized'

      expect(response).to have_http_status(:forbidden)
    end

    it '有効な場合は通します' do
      login_as(user)

      get '/spec/authorized'

      expect(response).to have_http_status(:ok)
    end
  end

  describe '開発環境での分岐' do
    it '開発環境では、指定した利用者として通ります' do
      allow(AppEnvironment).to receive(:developer_shortcuts_allowed?).and_return(true)
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('DEVELOPMENT_AUTO_LOGIN_X_USER_ID', nil)
                                   .and_return('1234567890')

      get '/spec/protected'

      expect(response).to have_http_status(:ok)
    end

    it '本番では、環境変数を設定しても通りません' do
      allow(AppEnvironment).to receive(:developer_shortcuts_allowed?).and_return(false)
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('DEVELOPMENT_AUTO_LOGIN_X_USER_ID', nil)
                                   .and_return('1234567890')

      get '/spec/protected'

      expect(response).to have_http_status(:unauthorized)
    end

    it '開発環境でも、環境変数が無ければ通りません' do
      allow(AppEnvironment).to receive(:developer_shortcuts_allowed?).and_return(true)
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('DEVELOPMENT_AUTO_LOGIN_X_USER_ID', nil).and_return(nil)

      get '/spec/protected'

      expect(response).to have_http_status(:unauthorized)
    end

    it 'リクエスト側の値では切り替わりません' do
      allow(AppEnvironment).to receive(:developer_shortcuts_allowed?).and_return(false)

      get '/spec/protected', headers: { 'X-Developer-Login' => '1234567890' },
                             params: { developer_login: '1234567890' }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
