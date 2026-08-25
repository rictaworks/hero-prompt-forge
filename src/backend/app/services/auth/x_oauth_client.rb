# frozen_string_literal: true

require 'net/http'
require 'json'
require 'securerandom'
require 'digest'
require 'base64'

module Auth
  # X ログイン（OAuth 2.0 + PKCE）です。
  #
  # 認可を受けて**数値のユーザーIDと表示名だけ**を取得します。
  # フォロワー判定はここで行いません（FollowerGateClient が担います）。
  #
  # 資格情報は環境変数から読みます。ソースへ書きません。
  class XOauthClient
    class UnavailableError < StandardError; end
    class UnauthorizedError < StandardError; end
    class InvalidResponseError < StandardError; end

    AUTHORIZE_URL = 'https://x.com/i/oauth2/authorize'
    TOKEN_URL = 'https://api.x.com/2/oauth2/token'
    ME_URL = 'https://api.x.com/2/users/me'

    # 利用条件の判定に必要な最小の範囲のみを要求します。
    SCOPES = %w[tweet.read users.read].freeze

    DEFAULT_TIMEOUT_SECONDS = 5

    # 認可へ送り出すための一式です。state と code_verifier は呼び出し側が
    # セッションへ保存し、戻ってきたときに照合します。
    Authorization = Struct.new(:url, :state, :code_verifier, keyword_init: true)

    # 認可の結果として得られる、本アプリが保持する情報です。
    Identity = Struct.new(:x_user_id, :display_name, keyword_init: true)

    def initialize(
      client_id: ENV.fetch('X_OAUTH_CLIENT_ID'),
      client_secret: ENV.fetch('X_OAUTH_CLIENT_SECRET'),
      redirect_uri: ENV.fetch('X_OAUTH_REDIRECT_URI'),
      timeout_seconds: DEFAULT_TIMEOUT_SECONDS
    )
      @client_id = client_id
      @client_secret = client_secret
      @redirect_uri = redirect_uri
      @timeout_seconds = timeout_seconds
    end

    # 認可画面へ送り出すための一式を作ります。
    def authorization
      state = SecureRandom.urlsafe_base64(32)
      code_verifier = SecureRandom.urlsafe_base64(64)

      Authorization.new(url: authorize_url(state, code_verifier),
                        state: state,
                        code_verifier: code_verifier)
    end

    # 認可コードを引き換えて、利用者の識別子と表示名を取得します。
    # @return [Identity]
    def exchange(code:, code_verifier:)
      Trace.step('x_oauth.exchange') do
        token = request_token(code: code, code_verifier: code_verifier)
        fetch_identity(token)
      end
    end

    private

    attr_reader :client_id, :client_secret, :redirect_uri, :timeout_seconds

    def authorize_url(state, code_verifier)
      uri = URI.parse(AUTHORIZE_URL)
      uri.query = URI.encode_www_form(authorize_params(state, code_verifier))
      uri.to_s
    end

    def authorize_params(state, code_verifier)
      {
        response_type: 'code',
        client_id: client_id,
        redirect_uri: redirect_uri,
        scope: SCOPES.join(' '),
        state: state,
        code_challenge: code_challenge(code_verifier),
        code_challenge_method: 'S256'
      }
    end

    def code_challenge(code_verifier)
      Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
    end

    def request_token(code:, code_verifier:)
      uri = URI.parse(TOKEN_URL)
      body = parse(perform(uri, token_request(uri, code, code_verifier)))
      token = body['access_token']
      raise InvalidResponseError, '応答にアクセストークンがありません。' if token.nil? # 開発者向け

      token
    end

    def token_request(uri, code, code_verifier)
      request = Net::HTTP::Post.new(uri)
      request.basic_auth(client_id, client_secret)
      request['Content-Type'] = 'application/x-www-form-urlencoded'
      request.body = URI.encode_www_form(
        grant_type: 'authorization_code',
        code: code,
        redirect_uri: redirect_uri,
        code_verifier: code_verifier
      )
      request
    end

    def fetch_identity(token)
      uri = URI.parse(ME_URL)
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{token}"
      request['Accept'] = 'application/json'

      data = parse(perform(uri, request))['data']
      raise InvalidResponseError, '応答に利用者の情報がありません。' if data.nil? # 開発者向け

      identity_from(data)
    end

    def identity_from(data)
      x_user_id = data['id']
      display_name = data['name']
      if x_user_id.nil? || display_name.nil?
        raise InvalidResponseError, '応答に識別子または表示名がありません。' # 開発者向け
      end

      Identity.new(x_user_id: x_user_id.to_s, display_name: display_name.to_s)
    end

    def perform(uri, request)
      Net::HTTP.start(uri.hostname, uri.port,
                      use_ssl: true,
                      open_timeout: timeout_seconds,
                      read_timeout: timeout_seconds) do |http|
        http.request(request)
      end
    rescue StandardError => e
      # 例外の中身に資格情報が混ざらないよう、種別のみを伝えます。
      raise UnavailableError, "X へ到達できません: #{e.class}" # 開発者向け
    end

    def parse(response)
      ensure_success(response)
      JSON.parse(response.body)
    rescue JSON::ParserError
      raise InvalidResponseError, 'X の応答を解釈できません。' # 開発者向け
    end

    def ensure_success(response)
      return if response.is_a?(Net::HTTPOK)

      case response
      when Net::HTTPUnauthorized, Net::HTTPForbidden
        raise UnauthorizedError, 'X が資格情報を受け付けませんでした。' # 開発者向け
      else
        raise UnavailableError, "X の応答が想定と異なります: #{response.code}" # 開発者向け
      end
    end
  end
end
