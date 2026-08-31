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

  # 呼び出しに使った接続そのものを取り出します。**待ち時間の上限を見るためです。**
  def connection
    captured = nil
    allow(Net::HTTP).to receive(:new).and_wrap_original do |original, *arguments|
      captured = original.call(*arguments)
    end

    refine

    captured
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

    # **項目名は `generation_config` です**（issue #160）。
    # LangChain 経由になり、Google の受け付ける 2 つの書き方のうち、
    # もとの項目名（下線区切り）で送るようになりました。**送る内容は同じです。**
    it '利用者を指せる値を送りません' do
      stub_request(:post, endpoint).to_return(status: 200, body: answer('first'))
      refine

      expect(sent_body.keys).to contain_exactly('contents', 'generation_config')
    end

    # **モデルの名前は URL が持ちます。** 本文へ重ねません。
    it 'モデルの名前を本文へ入れません' do
      stub_request(:post, endpoint).to_return(status: 200, body: answer('first'))
      refine

      expect(sent_body).not_to have_key('model')
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

  # **LangChain（`langchainrb`）を通します**（issue #160）。
  describe 'LangChain 経由であること' do
    it 'LangChain の呼び出し先を使います' do
      expect(Generation::LangchainGemini.ancestors).to include(Langchain::LLM::GoogleGemini)
    end

    it 'LangChain の呼び出しを通ります' do
      stub_request(:post, endpoint).to_return(status: 200, body: answer('first'))
      allow(Generation::LangchainGemini).to receive(:new).and_call_original

      refine

      expect(Generation::LangchainGemini).to have_received(:new)
    end

    # **API キーは環境変数から読みます。** ソースにも設定ファイルにも書きません。
    it '鍵を設定ファイルから読みません' do
      settings = Generation::LlmSettings.load

      expect(settings.values.join).not_to include('test-key')
    end

    # **鍵を URL へ載せません。** URL は記録に残ります。
    it '鍵を URL へ載せません' do
      stub_request(:post, endpoint).to_return(status: 200, body: answer('first'))

      refine

      expect(sent.last.uri.to_s).not_to include('test-key')
    end

    it '鍵を見出しで送ります' do
      stub_request(:post, endpoint).to_return(status: 200, body: answer('first'))

      refine

      expect(sent.last.headers['X-Goog-Api-Key']).to eq('test-key')
    end

    # **待ち続けません。** 上限を越えたら失敗させ、縮退へ回します。
    it '待ち時間の上限を設けます' do
      stub_request(:post, endpoint).to_timeout

      expect { refine }.to raise_error(described_class::RequestFailedError)
    end

    # **設定した秒数が、実際の呼び出しへ入っていることを確かめます。**
    #
    # 時間切れを起こすだけでは足りません。**上限の 3 行を丸ごと消しても、
    # 時間切れは起きます**（PR #176 のレビュー・要修正 3）。
    it '設定した秒数を、呼び出しへ入れます' do
      stub_request(:post, endpoint).to_return(status: 200, body: answer('first'))
      settings = Generation::LlmSettings.load

      expect(connection).to have_attributes(
        open_timeout: settings.fetch('open_timeout_seconds'),
        read_timeout: settings.fetch('read_timeout_seconds'),
        write_timeout: settings.fetch('write_timeout_seconds')
      )
    end

    # **呼び出し先は設定から決めます。**
    #
    # gem が組み立てた URL を使うと、**設定を直しても呼び出し先が変わりません**
    # （PR #176 のレビュー・要修正 1）。
    it '設定の呼び出し先へ送ります' do
      stub_request(:post, endpoint).to_return(status: 200, body: answer('first'))

      refine

      # **問い合わせの文字列を持ちません。** 鍵は見出しで送ります。
      expect(sent.last.uri).to have_attributes(
        scheme: 'https',
        host: 'generativelanguage.googleapis.com',
        path: '/v1beta/models/gemini-2.5-flash-lite:generateContent',
        query: nil
      )
    end

    it '設定を変えると、送り先も変わります' do
      elsewhere = 'https://example.invalid/v1beta/models/%<model>s:generateContent'
      allow(Generation::LlmSettings).to receive(:load)
        .and_return(Generation::LlmSettings.load.merge('endpoint' => elsewhere))
      stub_request(:post, 'https://example.invalid/v1beta/models/gemini-2.5-flash-lite:generateContent')
        .to_return(status: 200, body: answer('first'))

      refine

      expect(sent.last.uri.host).to eq('example.invalid')
    end

    # **langchainrb 組み込みの追跡は使いません。** 独自の LangsmithLogger を
    # 経由します（issue #200）。
    it 'LangChain 組み込みの追跡設定を持ちません' do
      expect(ENV.fetch('LANGCHAIN_TRACING_V2', nil)).to be_blank
    end

    # **書き間違いを飲み込みません。**
    it '書き間違いは、そのまま外へ出します' do
      allow_any_instance_of(Generation::LangchainGemini).to receive(:chat).and_raise(NoMethodError) # rubocop:disable RSpec/AnyInstance

      expect { refine }.to raise_error(NoMethodError)
    end

    # **応答に文が無い場合、応答そのものを記録へ流しません。**
    it '応答の中身を持ち越しません' do
      stub_request(:post, endpoint).to_return(status: 200, body: { 'error' => 'ひみつ' }.to_json)

      expect { refine }.to raise_error(described_class::RequestFailedError) { |error|
        expect(error.message).not_to include('ひみつ')
      }
    end
  end

  # **LangSmith への記録**（issue #200）。この持ち場は本業を止めません。
  describe 'LangSmith への記録' do
    def with_langsmith_key(value)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with(Generation::LangsmithLogger::API_KEY_VARIABLE).and_return(value)
    end

    it '成功したら記録します' do
      with_langsmith_key('langsmith-key')
      stub_request(:post, endpoint).to_return(status: 200, body: answer('first'))
      stub_request(:post, Generation::LangsmithLogger::ENDPOINT).to_return(status: 200, body: '{}')
      allow(Generation::LangsmithLogger).to receive(:log_success).and_call_original

      refine

      expect(Generation::LangsmithLogger).to have_received(:log_success)
        .with(hash_including(lines: lines, refined: %w[first]))
    end

    it '失敗したら記録します' do
      with_langsmith_key('langsmith-key')
      stub_request(:post, endpoint).to_return(status: 503, body: '')
      stub_request(:post, Generation::LangsmithLogger::ENDPOINT).to_return(status: 200, body: '{}')
      allow(Generation::LangsmithLogger).to receive(:log_failure).and_call_original

      expect { refine }.to raise_error(described_class::RequestFailedError)
      expect(Generation::LangsmithLogger).to have_received(:log_failure)
        .with(hash_including(lines: lines))
    end

    # **LangSmith への送信が落ちても、生成そのものは失敗しません。**
    it 'LangSmithへの送信が失敗しても、結果を返します' do
      with_langsmith_key('langsmith-key')
      stub_request(:post, endpoint).to_return(status: 200, body: answer('first'))
      stub_request(:post, Generation::LangsmithLogger::ENDPOINT).to_raise(SocketError)

      expect(refine).to eq(%w[first])
    end

    it '鍵が無ければ記録しません' do
      with_langsmith_key(nil)
      stub_request(:post, endpoint).to_return(status: 200, body: answer('first'))
      langsmith_stub = stub_request(:post, Generation::LangsmithLogger::ENDPOINT)

      refine

      expect(langsmith_stub).not_to have_been_requested
    end
  end
end
