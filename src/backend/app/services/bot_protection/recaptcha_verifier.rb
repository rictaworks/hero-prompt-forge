# frozen_string_literal: true

require 'net/http'

module BotProtection
  # reCAPTCHA v3 の照合です（requirements.md 5.2、issue #61）。
  #
  # **Bot 対策を自作しません**（CLAUDE.md）。得点の判定を Google へ委ねます。
  #
  # **秘密鍵は環境変数から読みます。** ソースにも設定ファイルにも書きません。
  # **鍵が無ければ、その場で失敗させます。** 既定へ寄せると、
  # **照合したつもりで照合していない状態**になります。
  #
  # **送るのは、画面が受け取った合図と、要求元のアドレスだけです。**
  # 利用者の識別子・セッション・入力した文章を送りません。
  #
  # **通らなかった理由を、利用者へそのまま返しません。** Google が返す
  # 理由の符号は、Bot 対策の内側の情報です。
  class RecaptchaVerifier
    # 秘密鍵が環境変数にない場合に投げます。
    class MissingSecretKeyError < StandardError; end

    # 照合そのものができなかった場合に投げます。
    class UnavailableError < StandardError; end

    # 照合の結果、通さないと判断した場合に投げます。
    class VerificationFailedError < StandardError
      attr_reader :kind

      def initialize(kind)
        @kind = kind
        super("reCAPTCHA の照合を通りませんでした: #{kind}") # 開発者向け
      end
    end

    # 秘密鍵を読む環境変数の名前です。
    SECRET_KEY_VARIABLE = 'RECAPTCHA_SECRET_KEY'

    # 照合そのものができなかったと扱う出来事です。
    #
    # **通信の失敗をすべて受け止めます。** 受け止め漏れがあると、
    # Google 側の不調が、そのまま理由の分からない失敗になります。
    FAILURES = [Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout,
                OpenSSL::SSL::SSLError, SocketError, SystemCallError, IOError].freeze

    # 通らなかった理由の種別です。**利用者へは返しません。**
    MISSING_TOKEN = 'missing_token'
    REJECTED = 'rejected'
    ACTION_MISMATCH = 'action_mismatch'
    LOW_SCORE = 'low_score'

    def initialize(settings: Settings.load)
      @settings = settings
    end

    # 秘密鍵を読みます。**入口を 1 つにします**（PR #168 のレビューより）。
    # 入口が 2 つあると、差し替えの取りこぼしが起きます。
    # @return [String, nil]
    def self.secret_key
      ENV.fetch(SECRET_KEY_VARIABLE, nil).presence
    end

    # 秘密鍵が用意されているかどうかを返します。
    def self.configured?
      secret_key.present?
    end

    # 照合します。通らなければ例外にします。
    # @param token [String, nil] 画面が受け取った合図です
    # @param remote_ip [String, nil] 要求元のアドレスです
    # @return [Float] 得点です
    def call(token:, remote_ip: nil)
      raise VerificationFailedError, MISSING_TOKEN if token.blank?

      traced { judged(request(token, remote_ip)) }
    end

    private

    attr_reader :settings

    def traced(&)
      Trace.step('bot_protection.recaptcha_verified',
                 action: settings.fetch('expected_action'), &)
    end

    # **通す条件をすべて満たしたときだけ、得点を返します。**
    def judged(result)
      raise VerificationFailedError, REJECTED unless result['success']
      raise VerificationFailedError, ACTION_MISMATCH unless action_matches?(result)

      score = result['score'].to_f
      raise VerificationFailedError, LOW_SCORE if score < settings.fetch('minimum_score')

      score
    end

    # **行動の名前を確かめます。** 確かめないと、別の画面で取った得点を
    # 使い回せます。
    def action_matches?(result)
      result['action'] == settings.fetch('expected_action')
    end

    def secret_key
      key = self.class.secret_key
      return key if key

      raise MissingSecretKeyError,
            "環境変数 #{SECRET_KEY_VARIABLE} が設定されていません。" # 開発者向け
    end

    def request(token, remote_ip)
      response = post(form(token, remote_ip))
      parse(response)
    end

    # **秘密鍵は本文へ載せます。** URL へ載せません。記録へ残ります。
    def form(token, remote_ip)
      values = { 'secret' => secret_key, 'response' => token }
      values['remoteip'] = remote_ip if remote_ip.present?
      values
    end

    def post(values)
      uri = URI.parse(settings.fetch('verification_endpoint'))
      http(uri).request(post_request(uri, values))
    rescue *FAILURES => e
      raise UnavailableError, "reCAPTCHA へ届きませんでした: #{e.class.name}" # 開発者向け
    end

    def post_request(uri, values)
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(values)
      request
    end

    def http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = settings.fetch('open_timeout_seconds')
      http.read_timeout = settings.fetch('read_timeout_seconds')
      http.write_timeout = settings.fetch('write_timeout_seconds')
      http
    end

    def parse(response)
      raise UnavailableError, "reCAPTCHA が #{response.code} を返しました" unless response.is_a?(Net::HTTPOK) # 開発者向け

      parsed = JSON.parse(response.body)
      return parsed if parsed.is_a?(Hash)

      raise UnavailableError, 'reCAPTCHA の応答の形が違います。' # 開発者向け
    rescue JSON::ParserError => e
      raise UnavailableError, "reCAPTCHA の応答を読めませんでした: #{e.class.name}" # 開発者向け
    end
  end
end
