# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe BotProtection::RecaptchaVerifier do
  let(:endpoint) { 'https://www.google.com/recaptcha/api/siteverify' }
  let(:secret) { 'test-secret' } # 開発者向け

  # 環境変数の値を差し替えます。**実際の環境を書き換えません。**
  def with_key(value)
    stub_env(:fetch, described_class::SECRET_KEY_VARIABLE, nil, value)
    stub_env(:[], described_class::SECRET_KEY_VARIABLE, value)
  end

  def stub_env(message, *arguments, value)
    allow(ENV).to receive(message).and_call_original
    allow(ENV).to receive(message).with(*arguments).and_return(value)
  end

  before { with_key(secret) }

  def stub_verification(body:, status: 200)
    stub_request(:post, endpoint).to_return(status: status, body: body.to_json,
                                            headers: { 'Content-Type' => 'application/json' })
  end

  def sent_keys(request)
    request.body.split('&').map { |pair| pair.split('=').first }.sort
  end

  # 既定の合図は、開発者向けの当たり障りのない値です。
  def verify(token: 'token-value')
    described_class.new.call(token: token, remote_ip: '203.0.113.10')
  end

  describe '通る場合' do
    before { stub_verification(body: { success: true, score: 0.9, action: 'generate_prompt' }) }

    it '得点を返します' do
      expect(verify).to eq(0.9)
    end

    # **秘密鍵を URL へ載せません。** 記録へ残ります。
    it '秘密鍵を URL へ載せません' do
      verify

      expect(a_request(:post, endpoint).with { |request| request.uri.query.to_s.include?(secret) })
        .not_to have_been_made
    end

    it '秘密鍵を本文で送ります' do
      verify

      expect(a_request(:post, endpoint).with { |request| request.body.include?("secret=#{secret}") })
        .to have_been_made
    end

    # **送るのは合図と要求元のアドレスだけです。**
    it '送る項目は 3 つだけです' do
      verify

      expect(a_request(:post, endpoint).with { |request| sent_keys(request) == %w[remoteip response secret] })
        .to have_been_made
    end
  end

  describe '通らない場合' do
    it '合図が無ければ失敗させます' do
      expect { verify(token: nil) }
        .to raise_error(described_class::VerificationFailedError)
    end

    it '合図が無ければ照合へ行きません' do
      stub_verification(body: { success: true, score: 0.9, action: 'generate_prompt' })

      begin
        verify(token: '')
      rescue described_class::VerificationFailedError
        nil
      end

      expect(a_request(:post, endpoint)).not_to have_been_made
    end

    # **別の理由で緑にならないようにします**（PR #168 のレビューより）。
    # 行動の名前と得点をそろえたうえで、`success` だけを偽にします。
    it '断られたら失敗させます' do
      stub_verification(body: { success: false, score: 0.9, action: 'generate_prompt',
                                'error-codes': ['invalid-input-response'] })

      expect { verify }.to raise_error(described_class::VerificationFailedError)
    end

    it '断られた理由の種別を持ちます' do
      stub_verification(body: { success: false, score: 0.9, action: 'generate_prompt' })

      expect { verify }
        .to raise_error(an_instance_of(described_class::VerificationFailedError)
                          .and(having_attributes(kind: described_class::REJECTED)))
    end

    # **行動の名前が違えば通しません。** 他の画面で取った得点を使い回せません。
    it '行動の名前が違えば失敗させます' do
      stub_verification(body: { success: true, score: 0.9, action: 'login' })

      expect { verify }.to raise_error(described_class::VerificationFailedError)
    end

    it '得点が下限に届かなければ失敗させます' do
      stub_verification(body: { success: true, score: 0.1, action: 'generate_prompt' })

      expect { verify }.to raise_error(described_class::VerificationFailedError)
    end

    it '下限ちょうどは通します' do
      stub_verification(body: { success: true, score: 0.5, action: 'generate_prompt' })

      expect(verify).to eq(0.5)
    end

    # **理由は種別だけを持ちます。**
    it '理由の種別を持ちます' do
      stub_verification(body: { success: true, score: 0.1, action: 'generate_prompt' })

      expect { verify }
        .to raise_error(an_instance_of(described_class::VerificationFailedError)
                          .and(having_attributes(kind: described_class::LOW_SCORE)))
    end
  end

  describe '照合そのものができない場合' do
    it '応答が 200 でなければ、照合できなかったものとして扱います' do
      stub_verification(body: {}, status: 500)

      expect { verify }.to raise_error(described_class::UnavailableError)
    end

    it '応答を読めなければ、照合できなかったものとして扱います' do
      stub_request(:post, endpoint).to_return(status: 200, body: 'not json') # 開発者向け

      expect { verify }.to raise_error(described_class::UnavailableError)
    end

    # **通信の失敗をすべて受け止めます。** 受け止め漏れがあると、
    # 理由の分からない失敗になります。
    described_class::FAILURES.each do |failure|
      it "#{failure} を受け止めます" do
        stub_request(:post, endpoint).to_raise(failure)

        expect { verify }.to raise_error(described_class::UnavailableError)
      end
    end
  end

  describe '秘密鍵が無い場合' do
    before { with_key(nil) }

    # **既定へ寄せません。** 照合したつもりで照合していない状態を作りません。
    it 'その場で失敗させます' do
      expect { verify }.to raise_error(described_class::MissingSecretKeyError)
    end

    it '用意されていないことを答えます' do
      expect(described_class).not_to be_configured
    end
  end

  # **設定の誤りは、設定の誤りとしてその場で失敗させます**
  # （PR #168 のレビューより）。500 として利用者へ届けません。
  describe '設定' do
    def written(values)
      path = "tmp/recaptcha_#{values.hash.abs}.yml" # 開発者向け
      Rails.root.join(path).write(values.to_yaml)
      path
    end

    def sound
      {
        'verification_endpoint' => 'https://www.google.com/recaptcha/api/siteverify',
        'minimum_score' => 0.5,
        'expected_action' => 'generate_prompt',
        'open_timeout_seconds' => 3,
        'read_timeout_seconds' => 5,
        'write_timeout_seconds' => 3
      }
    end

    it '項目が欠けていれば失敗させます' do
      expect { BotProtection::Settings.load(path: 'config/does_not_exist.yml') }
        .to raise_error(BotProtection::Settings::InvalidSettingsError)
    end

    it 'そろっていれば読めます' do
      expect(BotProtection::Settings.load(path: written(sound))).to include('minimum_score' => 0.5)
    end

    {
      '得点が文字列' => { 'minimum_score' => '0.5' },
      '得点が範囲の外' => { 'minimum_score' => 1.5 },
      '待つ秒数が文字列' => { 'read_timeout_seconds' => '5' },
      '待つ秒数が 0' => { 'open_timeout_seconds' => 0 },
      '行動の名前が空' => { 'expected_action' => '' },
      '照合先が https ではありません' => {
        'verification_endpoint' => 'http://www.google.com/recaptcha/api/siteverify'
      }
    }.each do |name, wrong|
      it "#{name}なら失敗させます" do
        expect { BotProtection::Settings.load(path: written(sound.merge(wrong))) }
          .to raise_error(BotProtection::Settings::InvalidSettingsError)
      end
    end
  end
end
