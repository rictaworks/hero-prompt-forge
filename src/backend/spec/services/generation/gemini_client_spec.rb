# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Generation::GeminiClient do
  let(:endpoint) do
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent'
  end

  let(:client) { described_class.new }
  let(:lines) { ['a calm office', 'clear copy space on the left'] }
  # 送った内容を控えます。**中身を確かめるためです。**
  let(:sent) { [] }

  def with_key(value)
    stub_env(:fetch, described_class::API_KEY_VARIABLE, nil, value)
    stub_env(:[], described_class::API_KEY_VARIABLE, value)
  end

  def stub_env(message, *arguments, value)
    allow(ENV).to receive(message).and_call_original
    allow(ENV).to receive(message).with(*arguments).and_return(value)
  end

  def answer(text)
    { candidates: [{ content: { parts: [{ text: text }] } }] }.to_json
  end

  def refine
    client.refine(instruction: 'Refine these fragments.', lines: lines)
  end

  before do
    with_key('test-key')
    requests = sent
    WebMock.after_request { |request, _response| requests << request }
  end

  describe '磨いた文の受け取り' do
    it '行ごとに分けて返します' do
      stub_request(:post, endpoint).to_return(status: 200, body: answer("first\nsecond"))

      expect(refine).to eq(%w[first second])
    end

    it '空の行を落とします' do
      stub_request(:post, endpoint).to_return(status: 200, body: answer("first\n\nsecond\n"))

      expect(refine).to eq(%w[first second])
    end
  end

  # **鍵は見出しで渡します。URL へ載せません。**
  describe '鍵の渡し方' do
    it '見出しへ載せます' do
      stub = stub_request(:post, endpoint)
             .with(headers: { described_class::API_KEY_HEADER => 'test-key' })
             .to_return(status: 200, body: answer('first'))
      refine

      expect(stub).to have_been_requested
    end

    it 'URL へ載せません' do
      stub_request(:post, endpoint).to_return(status: 200, body: answer('first'))
      refine

      expect(a_request(:post, /test-key/)).not_to have_been_made
    end

    # **鍵が無ければ、その場で失敗させます。**
    it '鍵が無ければ失敗します' do
      with_key(nil)

      expect { refine }.to raise_error(described_class::MissingApiKeyError)
    end

    it '鍵が空でも失敗します' do
      with_key('')

      expect { refine }.to raise_error(described_class::MissingApiKeyError)
    end
  end

  # **送るのは、指示文と磨く対象の英文だけです。**
  describe '送る内容' do
    it '指示文と素材だけを送ります' do
      expected = "Refine these fragments.\n\n#{lines.join("\n")}"
      stub = stub_request(:post, endpoint).to_return(status: 200, body: answer('first'))
      refine

      expect(stub).to have_been_requested
      expect(sent_text).to eq(expected)
    end

    it '利用者を指せる値を送りません' do
      stub_request(:post, endpoint).to_return(status: 200, body: answer('first'))
      refine

      expect(sent_body.keys).to contain_exactly('contents', 'generationConfig')
    end

    def sent_body
      JSON.parse(sent.last.body)
    end

    def sent_text
      sent_body.dig('contents', 0, 'parts', 0, 'text')
    end
  end

  # **通信の失敗は、すべて呼び出しの失敗として扱います。**
  describe '呼び出しの失敗' do
    it '応答が成功でなければ失敗します' do
      stub_request(:post, endpoint).to_return(status: 503, body: '')

      expect { refine }.to raise_error(described_class::RequestFailedError)
    end

    it '応答が読めなければ失敗します' do
      stub_request(:post, endpoint).to_return(status: 200, body: '壊れています')

      expect { refine }.to raise_error(described_class::RequestFailedError)
    end

    it '応答に文が無ければ失敗します' do
      stub_request(:post, endpoint).to_return(status: 200, body: { candidates: [] }.to_json)

      expect { refine }.to raise_error(described_class::RequestFailedError)
    end

    [Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, SocketError, Errno::ECONNRESET]
      .each do |failure|
      it "#{failure} なら呼び出しの失敗として扱います" do
        stub_request(:post, endpoint).to_raise(failure)

        expect { refine }.to raise_error(described_class::RequestFailedError)
      end
    end

    # **例外に鍵を載せません。**
    it '例外に鍵を含めません' do
      stub_request(:post, endpoint).to_return(status: 503, body: '')

      expect { refine }.to raise_error(described_class::RequestFailedError) { |error|
        expect(error.message).not_to include('test-key')
      }
    end
  end

  describe '使えるかどうか' do
    it '鍵があれば使えます' do
      expect(described_class).to be_available
    end

    it '鍵が無ければ使えません' do
      with_key(nil)

      expect(described_class).not_to be_available
    end
  end
end
