# frozen_string_literal: true

require 'langchain'

module Generation
  # LangChain（Ruby 版 `langchainrb`）の Gemini 呼び出しです（issue #160）。
  #
  # **仕様の技術スタックが LangChain を挙げています**（requirements.md 3）。
  # 呼び出しの組み立てと応答の読み取りは、そちらへ委ねます。
  #
  # **ただし、次の 2 点だけは、この持ち場で上書きします。**
  #
  # ## 1. API キーを URL へ載せません
  #
  # `langchainrb` の既定は、キーを問い合わせの文字列（`?key=...`）へ載せます。
  # **URL は記録に残ります**（アクセスログ・中継の記録・例外の記録）。
  # 見出しで送れば残りません。**この持ち場は、そのために存在します。**
  #
  # ## 2. 待ち続けません
  #
  # `langchainrb` は待ち時間の上限を設けません。**外への呼び出しが返らない
  # 場合、ジョブがそのまま止まります。** 上限を設け、越えたら失敗させて
  # 縮退（issue #53）へ回します。
  #
  # **送る内容は変えません。** 指示文と磨く対象の英文だけです。
  # 認証情報・利用者の識別子・セッションを送りません。
  class LangchainGemini < Langchain::LLM::GoogleGemini
    # キーを載せる見出しです。**URL へ載せません。**
    API_KEY_HEADER = 'x-goog-api-key'

    # @param api_key [String] 環境変数から読んだ鍵です
    # @param default_options [Hash] 既定の設定です
    # @param timeouts [Hash] `open` ・ `read` ・ `write` の秒数です
    def initialize(api_key:, timeouts:, default_options: {})
      super(api_key: api_key, default_options: default_options)
      @timeouts = timeouts
    end

    # 送る本文から落とす項目です。
    #
    # **モデルの名前は URL が持ちます。** 本文にも入れると、送る内容が増えます。
    # **送る内容は最小限にとどめます**（issue #160 の受け入れ条件）。
    DROPPED_PARAMS = %i[model].freeze

    private

    attr_reader :timeouts

    # **キーを見出しで送り、URL から落とします。**
    def http_post(url, params)
      target = without_key(url)
      http = client_for(target)
      response = http.request(request_for(target, params.except(*DROPPED_PARAMS)))

      JSON.parse(response.body)
    end

    # 問い合わせの文字列を落とします。**キーはここに載りません。**
    def without_key(url)
      target = URI(url.to_s)
      target.query = nil
      target
    end

    def client_for(target)
      http = Net::HTTP.new(target.hostname, target.port)
      http.use_ssl = target.scheme == 'https'
      http.open_timeout = timeouts.fetch(:open)
      http.read_timeout = timeouts.fetch(:read)
      http.write_timeout = timeouts.fetch(:write)
      http
    end

    def request_for(target, params)
      request = Net::HTTP::Post.new(target)
      request.content_type = 'application/json'
      request[API_KEY_HEADER] = api_key
      request.body = params.to_json
      request
    end
  end
end
