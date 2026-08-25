# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FollowerGateClient do
  subject(:client) do
    described_class.new(base_url: 'https://gate.example.test',
                        client_id: 'hero-prompt-forge',
                        credential: 'test_credential')
  end

  let(:endpoint) { 'https://gate.example.test/internal/decision' }

  def stub_decision(status:, body:)
    stub_request(:get, endpoint)
      .with(query: { x_user_id: '1234567890' })
      .to_return(status: status, body: body.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  describe '#decide' do
    it 'プラン値をそのまま返します' do
      stub_decision(status: 200,
                    body: { plan: 'full', decided_at: '2026-08-25T10:00:00+09:00',
                            recheck_available: false, inquiry_id: 'abc', confirmed: true })

      expect(client.decide(x_user_id: '1234567890').plan).to eq('full')
    end

    it '応答の項目をそのまま保持します' do
      stub_decision(status: 200,
                    body: { plan: 'restricted', decided_at: '2026-08-25T10:00:00+09:00',
                            recheck_available: true, inquiry_id: 'inq-1', confirmed: true })

      decision = client.decide(x_user_id: '1234567890')

      expect([decision.recheck_available, decision.inquiry_id, decision.confirmed])
        .to eq([true, 'inq-1', true])
    end

    it '資格情報を付けて呼び出します' do
      stub_decision(status: 200, body: { plan: 'full', confirmed: true })

      client.decide(x_user_id: '1234567890')

      expect(a_request(:get, endpoint)
        .with(query: { x_user_id: '1234567890' },
              headers: { 'Authorization' => 'Bearer hero-prompt-forge:test_credential' }))
        .to have_been_made
    end

    it '確定していない判定も、そのまま伝えます' do
      stub_decision(status: 200, body: { plan: 'restricted', confirmed: false })

      expect(client.decide(x_user_id: '1234567890').confirmed).to be(false)
    end
  end

  describe '失敗の扱い' do
    it '資格情報が受け付けられない場合は例外にします' do
      stub_decision(status: 401, body: { error: 'unauthorized' })

      expect { client.decide(x_user_id: '1234567890') }
        .to raise_error(described_class::UnauthorizedError)
    end

    it '識別子が受け付けられない場合は例外にします' do
      stub_decision(status: 400, body: { error: 'invalid_x_user_id' })

      expect { client.decide(x_user_id: '1234567890') }
        .to raise_error(described_class::InvalidUserIdError)
    end

    it '上限に達した場合は到達不能として扱います' do
      stub_decision(status: 429, body: { error: 'too_many_requests' })

      expect { client.decide(x_user_id: '1234567890') }
        .to raise_error(described_class::UnavailableError)
    end

    it '到達できない場合は例外にします' do
      stub_request(:get, endpoint).with(query: { x_user_id: '1234567890' }).to_timeout

      expect { client.decide(x_user_id: '1234567890') }
        .to raise_error(described_class::UnavailableError)
    end

    it '応答を解釈できない場合は例外にします' do
      stub_request(:get, endpoint)
        .with(query: { x_user_id: '1234567890' })
        .to_return(status: 200, body: 'not json')

      expect { client.decide(x_user_id: '1234567890') }
        .to raise_error(described_class::UnavailableError)
    end

    it 'プラン値が無い応答は例外にします' do
      stub_decision(status: 200, body: { decided_at: '2026-08-25T10:00:00+09:00' })

      expect { client.decide(x_user_id: '1234567890') }
        .to raise_error(described_class::UnavailableError)
    end

    it '失敗しても既定のプラン値へ寄せません' do
      stub_decision(status: 500, body: { error: 'internal' })

      expect { client.decide(x_user_id: '1234567890') }
        .to raise_error(described_class::UnavailableError)
    end

    it '例外に接続先や資格情報を含めません' do
      stub_request(:get, endpoint).with(query: { x_user_id: '1234567890' }).to_timeout

      client.decide(x_user_id: '1234567890')
    rescue described_class::UnavailableError => e
      expect(e.message).not_to include('gate.example.test', 'test_credential')
    end
  end

  describe '識別子の検証' do
    it '数字以外を受け付けません' do
      expect { client.decide(x_user_id: 'ao_design') }
        .to raise_error(described_class::InvalidUserIdError)
    end

    it '空の値を受け付けません' do
      expect { client.decide(x_user_id: '') }
        .to raise_error(described_class::InvalidUserIdError)
    end

    it '不正な識別子では通信しません' do
      expect { client.decide(x_user_id: 'ao_design') }
        .to raise_error(described_class::InvalidUserIdError)

      expect(a_request(:get, endpoint)).not_to have_been_made
    end
  end

  describe '設定' do
    it '接続先が未設定なら作れません' do
      allow(ENV).to receive(:fetch).with('FOLLOWER_GATE_BASE_URL').and_raise(KeyError)

      expect { described_class.new }.to raise_error(KeyError)
    end
  end
end
