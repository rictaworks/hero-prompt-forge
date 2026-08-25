# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'X ログイン' do # rubocop:disable RSpec/DescribeClass
  let(:frontend) { 'http://localhost:3300' }
  let(:gate_client) { instance_double(FollowerGateClient) }

  before do
    allow(FollowerGateClient).to receive(:new).and_return(gate_client)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('FRONTEND_BASE_URL').and_return(frontend)
    allow(ENV).to receive(:fetch).with('X_OAUTH_CLIENT_ID').and_return('test_client')
    allow(ENV).to receive(:fetch).with('X_OAUTH_CLIENT_SECRET').and_return('test_secret')
    allow(ENV).to receive(:fetch).with('X_OAUTH_REDIRECT_URI')
                                 .and_return('http://localhost:3301/auth/callback')
  end

  describe 'GET /auth/start' do
    it '認可の画面へ送り出します' do
      get '/auth/start'

      expect(response).to have_http_status(:found)
    end

    it '送り先は X の認可の画面です' do
      get '/auth/start'

      expect(response.location).to start_with('https://x.com/i/oauth2/authorize?')
    end

    it '照合値と検証値を控えます' do
      get '/auth/start'

      expect(cookies.to_hash.keys).to include('hpf_oauth_state', 'hpf_oauth_verifier')
    end

    it '検証値を送り先へ平文で渡しません' do
      get '/auth/start'
      query = URI.decode_www_form(URI.parse(response.location).query).to_h

      expect(query['code_challenge_method']).to eq('S256')
    end
  end

  describe 'GET /auth/callback' do
    def stub_x(user_id: '1234567890', name: 'あお')
      stub_request(:post, 'https://api.x.com/2/oauth2/token')
        .to_return(status: 200, body: { access_token: 'token_value' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, 'https://api.x.com/2/users/me')
        .to_return(status: 200, body: { data: { id: user_id, name: name } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })
    end

    def stub_gate(plan: 'full')
      allow(gate_client).to receive(:decide)
        .and_return(FollowerGateClient::Decision.new(plan: plan, confirmed: true,
                                                     decided_at: nil,
                                                     recheck_available: false,
                                                     inquiry_id: nil))
    end

    def start_and_state
      get '/auth/start'
      URI.decode_www_form(URI.parse(response.location).query).to_h['state']
    end

    it '利用者を作ります' do
      state = start_and_state
      stub_x
      stub_gate

      expect { get '/auth/callback', params: { code: 'auth_code', state: state } }
        .to change(User, :count).by(1)
    end

    it 'プラン値を反映します' do
      state = start_and_state
      stub_x
      stub_gate(plan: 'full')

      get '/auth/callback', params: { code: 'auth_code', state: state }

      expect(User.last.plan).to eq('active')
    end

    it 'ログイン状態を作ります' do
      state = start_and_state
      stub_x
      stub_gate

      expect { get '/auth/callback', params: { code: 'auth_code', state: state } }
        .to change(Session, :count).by(1)
    end

    it '画面へ戻します' do
      state = start_and_state
      stub_x
      stub_gate

      get '/auth/callback', params: { code: 'auth_code', state: state }

      expect(response.location).to eq("#{frontend}/projects")
    end

    it '照合値が違う場合は利用者を作りません' do
      start_and_state
      stub_x
      stub_gate

      expect { get '/auth/callback', params: { code: 'auth_code', state: 'wrong' } }
        .not_to change(User, :count)
    end

    it '照合値が違う場合は失敗として戻します' do
      start_and_state

      get '/auth/callback', params: { code: 'auth_code', state: 'wrong' }

      expect(response.location).to eq("#{frontend}/login?reason=invalid_state")
    end

    it '照合値が無い場合も失敗として戻します' do
      get '/auth/callback', params: { code: 'auth_code', state: 'anything' }

      expect(response.location).to eq("#{frontend}/login?reason=invalid_state")
    end

    it 'X が受け付けない場合は失敗として戻します' do
      state = start_and_state
      stub_request(:post, 'https://api.x.com/2/oauth2/token')
        .to_return(status: 401, body: { error: 'invalid_client' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      get '/auth/callback', params: { code: 'auth_code', state: state }

      expect(response.location).to eq("#{frontend}/login?reason=rejected")
    end

    it 'X へ到達できない場合は失敗として戻します' do
      state = start_and_state
      stub_request(:post, 'https://api.x.com/2/oauth2/token').to_timeout

      get '/auth/callback', params: { code: 'auth_code', state: state }

      expect(response.location).to eq("#{frontend}/login?reason=unavailable")
    end

    it '同じ方が二度ログインしても利用者は増えません' do
      User.create!(x_user_id: '1234567890', display_name: '古い名前')
      state = start_and_state
      stub_x
      stub_gate

      expect { get '/auth/callback', params: { code: 'auth_code', state: state } }
        .not_to change(User, :count)
    end

    it '表示名を最新にします' do
      User.create!(x_user_id: '1234567890', display_name: '古い名前')
      state = start_and_state
      stub_x
      stub_gate

      get '/auth/callback', params: { code: 'auth_code', state: state }

      expect(User.find_by(x_user_id: '1234567890').display_name).to eq('あお')
    end
  end

  describe 'DELETE /auth/session' do
    it 'ログイン状態を取り消します' do
      user = User.create!(x_user_id: '1234567890', display_name: 'あお', plan: 'active')
      login_as(user)

      delete '/auth/session'

      expect(Session.last.revoked_at).to be_present
    end

    it '画面へ戻します' do
      user = User.create!(x_user_id: '1234567890', display_name: 'あお', plan: 'active')
      login_as(user)

      delete '/auth/session'

      expect(response.location).to eq(frontend)
    end
  end
end
