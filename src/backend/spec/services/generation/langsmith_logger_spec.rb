# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Generation::LangsmithLogger do
  let(:endpoint) { described_class::ENDPOINT }
  let(:started_at) { Time.zone.local(2026, 8, 31, 8, 0, 0) }
  let(:finished_at) { Time.zone.local(2026, 8, 31, 8, 0, 1) }

  def with_key(value)
    stub_env(:fetch, described_class::API_KEY_VARIABLE, nil, value)
    stub_env(:[], described_class::API_KEY_VARIABLE, value)
  end

  def stub_env(message, *arguments, value)
    allow(ENV).to receive(message).and_call_original
    allow(ENV).to receive(message).with(*arguments).and_return(value)
  end

  before { with_key('test-langsmith-key') }

  describe '.available?' do
    it '鍵があれば使えます' do
      expect(described_class).to be_available
    end

    it '鍵が無ければ使えません' do
      with_key(nil)

      expect(described_class).not_to be_available
    end
  end

  describe '.log_success' do
    it '鍵があれば送ります' do
      stub = stub_request(:post, endpoint).to_return(status: 200, body: '{}')

      described_class.log_success(instruction: 'Refine.', lines: ['a calm office'],
                                  refined: ['a calm, quiet office'], model: 'gemini-2.5-flash-lite',
                                  started_at: started_at, finished_at: finished_at)

      expect(stub).to have_been_requested
    end

    it '鍵が無ければ送りません' do
      with_key(nil)
      stub = stub_request(:post, endpoint)

      described_class.log_success(instruction: 'Refine.', lines: ['a calm office'],
                                  refined: ['a calm, quiet office'], model: 'gemini-2.5-flash-lite',
                                  started_at: started_at, finished_at: finished_at)

      expect(stub).not_to have_been_requested
    end

    it '鍵を見出しで送ります' do
      stub_request(:post, endpoint)
        .with(headers: { 'x-api-key' => 'test-langsmith-key' })
        .to_return(status: 200, body: '{}')

      described_class.log_success(instruction: 'Refine.', lines: ['a calm office'],
                                  refined: ['a calm, quiet office'], model: 'gemini-2.5-flash-lite',
                                  started_at: started_at, finished_at: finished_at)

      expect(a_request(:post, endpoint).with(headers: { 'x-api-key' => 'test-langsmith-key' }))
        .to have_been_made
    end

    it '指示文・素材・返ってきた文だけを送ります' do
      stub_request(:post, endpoint).to_return(status: 200, body: '{}')

      described_class.log_success(instruction: 'Refine.', lines: ['a calm office'],
                                  refined: ['a calm, quiet office'], model: 'gemini-2.5-flash-lite',
                                  started_at: started_at, finished_at: finished_at)

      body = JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last.body)

      expect(body['inputs']).to eq('instruction' => 'Refine.', 'lines' => ['a calm office'],
                                   'model' => 'gemini-2.5-flash-lite')
      expect(body['outputs']).to eq('refined' => ['a calm, quiet office'])
      expect(body).not_to have_key('error')
    end

    # **本業を止めません。** 通信が失敗しても、呼び出す側へ投げません。
    it '送信が失敗しても例外を投げません' do
      stub_request(:post, endpoint).to_raise(SocketError)

      expect do
        described_class.log_success(instruction: 'Refine.', lines: ['a calm office'],
                                    refined: ['a calm, quiet office'], model: 'gemini-2.5-flash-lite',
                                    started_at: started_at, finished_at: finished_at)
      end.not_to raise_error
    end
  end

  describe '.log_failure' do
    it '鍵があれば送ります' do
      stub = stub_request(:post, endpoint).to_return(status: 200, body: '{}')

      described_class.log_failure(instruction: 'Refine.', lines: ['a calm office'],
                                  model: 'gemini-2.5-flash-lite', started_at: started_at,
                                  finished_at: finished_at,
                                  error: Generation::GeminiClient::RequestFailedError.new('timeout'))

      expect(stub).to have_been_requested
    end

    it '失敗の種別だけを送ります' do
      stub_request(:post, endpoint).to_return(status: 200, body: '{}')

      described_class.log_failure(instruction: 'Refine.', lines: ['a calm office'],
                                  model: 'gemini-2.5-flash-lite', started_at: started_at,
                                  finished_at: finished_at,
                                  error: Generation::GeminiClient::RequestFailedError.new('timeout'))

      body = JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last.body)

      expect(body['error']).to eq('timeout')
      expect(body).not_to have_key('outputs')
    end
  end
end
