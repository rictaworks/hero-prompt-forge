# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::XOauthClient do
  subject(:client) do
    described_class.new(client_id: 'test_client',
                        client_secret: 'test_secret',
                        redirect_uri: 'https://app.example.test/auth/callback')
  end

  describe '#authorization' do
    it '認可の経路を作ります' do
      expect(client.authorization.url).to start_with('https://x.com/i/oauth2/authorize?')
    end

    it '毎回異なる照合値を作ります' do
      expect(client.authorization.state).not_to eq(client.authorization.state)
    end

    it '毎回異なる検証値を作ります' do
      expect(client.authorization.code_verifier).not_to eq(client.authorization.code_verifier)
    end

    it '検証値を平文で送りません' do
      authorization = client.authorization
      query = URI.decode_www_form(URI.parse(authorization.url).query).to_h

      expect(query['code_challenge']).not_to eq(authorization.code_verifier)
    end

    it '検証値の変換方式を明示します' do
      query = URI.decode_www_form(URI.parse(client.authorization.url).query).to_h

      expect(query['code_challenge_method']).to eq('S256')
    end

    it '要求する範囲を最小限にします' do
      query = URI.decode_www_form(URI.parse(client.authorization.url).query).to_h

      expect(query['scope']).to eq('tweet.read users.read')
    end
  end

  describe '#exchange' do
    def stub_token(status: 200, body: { access_token: 'token_value' })
      stub_request(:post, 'https://api.x.com/2/oauth2/token')
        .to_return(status: status, body: body.to_json,
                   headers: { 'Content-Type' => 'application/json' })
    end

    def stub_me(status: 200, body: { data: { id: '1234567890', name: 'あお' } })
      stub_request(:get, 'https://api.x.com/2/users/me')
        .to_return(status: status, body: body.to_json,
                   headers: { 'Content-Type' => 'application/json' })
    end

    it '識別子と表示名を取得します' do
      stub_token
      stub_me

      identity = client.exchange(code: 'auth_code', code_verifier: 'verifier')

      expect([identity.x_user_id, identity.display_name]).to eq(%w[1234567890 あお])
    end

    it '検証値を添えて引き換えます' do
      stub_token
      stub_me

      client.exchange(code: 'auth_code', code_verifier: 'verifier')

      expect(a_request(:post, 'https://api.x.com/2/oauth2/token')
        .with(body: hash_including('code_verifier' => 'verifier')))
        .to have_been_made
    end

    it '取得したトークンで利用者を照会します' do
      stub_token
      stub_me

      client.exchange(code: 'auth_code', code_verifier: 'verifier')

      expect(a_request(:get, 'https://api.x.com/2/users/me')
        .with(headers: { 'Authorization' => 'Bearer token_value' }))
        .to have_been_made
    end

    it '資格情報が受け付けられない場合は例外にします' do
      stub_token(status: 401, body: { error: 'invalid_client' })

      expect { client.exchange(code: 'auth_code', code_verifier: 'verifier') }
        .to raise_error(described_class::UnauthorizedError)
    end

    it 'トークンが無い応答は例外にします' do
      stub_token(body: { token_type: 'bearer' })

      expect { client.exchange(code: 'auth_code', code_verifier: 'verifier') }
        .to raise_error(described_class::InvalidResponseError)
    end

    it '利用者の情報が無い応答は例外にします' do
      stub_token
      stub_me(body: { errors: [] })

      expect { client.exchange(code: 'auth_code', code_verifier: 'verifier') }
        .to raise_error(described_class::InvalidResponseError)
    end

    it '識別子が無い応答は例外にします' do
      stub_token
      stub_me(body: { data: { name: 'あお' } })

      expect { client.exchange(code: 'auth_code', code_verifier: 'verifier') }
        .to raise_error(described_class::InvalidResponseError)
    end

    it '到達できない場合は例外にします' do
      stub_request(:post, 'https://api.x.com/2/oauth2/token').to_timeout

      expect { client.exchange(code: 'auth_code', code_verifier: 'verifier') }
        .to raise_error(described_class::UnavailableError)
    end

    it '失敗しても利用者を作りません' do
      stub_token(status: 500, body: { error: 'internal' })

      expect { client.exchange(code: 'auth_code', code_verifier: 'verifier') }
        .to raise_error(described_class::UnavailableError)
    end

    it '例外に資格情報を含めません' do
      stub_request(:post, 'https://api.x.com/2/oauth2/token').to_timeout

      client.exchange(code: 'auth_code', code_verifier: 'verifier')
    rescue described_class::UnavailableError => e
      expect(e.message).not_to include('test_secret', 'test_client')
    end
  end

  describe '設定' do
    it '資格情報が未設定なら作れません' do
      allow(ENV).to receive(:fetch).with('X_OAUTH_CLIENT_ID').and_raise(KeyError)

      expect { described_class.new }.to raise_error(KeyError)
    end
  end
end
