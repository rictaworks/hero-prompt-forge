# frozen_string_literal: true

require 'net/http'

module Generation
  # Gemini への呼び出しです（requirements.md 4.1 の 10）。
  #
  # **API キーを環境変数から読みます。** ソースにも設定ファイルにも書きません。
  # **キーが無ければ、その場で失敗させます。** 既定へ寄せると、精緻化を
  # 行ったつもりで行われていない状態になります。
  #
  # **送るのは、磨く対象の英文と、利用者が選んだ条件だけです。**
  # 認証情報・利用者の識別子・セッションを送りません。
  #
  # **待ち続けません。** 越えたら失敗させ、縮退（issue #53）へ回します。
  class GeminiClient
    # API キーが環境変数にない場合に投げます。
    class MissingApiKeyError < StandardError; end

    # 呼び出しが失敗した場合に投げます。
    class RequestFailedError < StandardError; end

    # API キーを読む環境変数の名前です。
    API_KEY_VARIABLE = 'GEMINI_API_KEY'

    # キーを載せる見出しです。**URL へ載せません。** 記録へ残ります。
    API_KEY_HEADER = 'x-goog-api-key'

    # 呼び出しの失敗として扱う出来事です。
    #
    # **通信の失敗をすべて受け止めます。** 受け止め漏れがあると、
    # 縮退（issue #53）へ回らず、生成そのものが落ちます
    # （PR #162 のレビューより）。
    FAILURES = [Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout,
                OpenSSL::SSL::SSLError, SocketError, SystemCallError, IOError].freeze

    def initialize(settings: LlmSettings.load)
      @settings = settings
    end

    # API キーが用意されているかどうかを返します。
    def self.available?
      ENV[API_KEY_VARIABLE].present?
    end

    # 磨いた文の並びを返します。
    # @param instruction [String] 指示文です
    # @param lines [Array<String>] 磨く対象の英文です
    # @return [Array<String>]
    def refine(instruction:, lines:)
      body = request_body(instruction, lines)

      traced(lines) { parse(post(body)) }
    end

    private

    attr_reader :settings

    def traced(lines, &)
      Trace.step('generation.llm_requested',
                 model: settings.fetch('model'), lines: lines.size, &)
    end

    def api_key
      key = ENV.fetch(API_KEY_VARIABLE, nil)
      return key if key.present?

      raise MissingApiKeyError,
            "環境変数 #{API_KEY_VARIABLE} が設定されていません。" # 開発者向け
    end

    def endpoint
      URI.parse(Kernel.format(settings.fetch('endpoint'), model: settings.fetch('model')))
    end

    # **送るのは、指示文と磨く対象の英文だけです。**
    def request_body(instruction, lines)
      { contents: [{ role: 'user', parts: [{ text: "#{instruction}\n\n#{lines.join("\n")}" }] }],
        generationConfig: { temperature: settings.fetch('temperature'),
                            maxOutputTokens: settings.fetch('max_output_tokens') } }
    end

    def post(body)
      response = http.request(request(body))
      return response.body if response.is_a?(Net::HTTPSuccess)

      raise RequestFailedError,
            "LLM の呼び出しが失敗しました: #{response.code}" # 開発者向け
    rescue *FAILURES => e
      raise RequestFailedError, "LLM の呼び出しが失敗しました: #{e.class}" # 開発者向け
    end

    def http
      client = Net::HTTP.new(endpoint.host, endpoint.port)
      client.use_ssl = true
      client.open_timeout = settings.fetch('open_timeout_seconds')
      client.read_timeout = settings.fetch('read_timeout_seconds')
      client.write_timeout = settings.fetch('write_timeout_seconds')
      client
    end

    def request(body)
      built = Net::HTTP::Post.new(endpoint.request_uri)
      built['content-type'] = 'application/json'
      built[API_KEY_HEADER] = api_key
      built.body = body.to_json
      built
    end

    # **返ってきた形が違えば、その場で失敗させます。**
    def parse(payload)
      parsed = JSON.parse(payload)
      text = parsed.dig('candidates', 0, 'content', 'parts', 0, 'text')
      raise RequestFailedError, 'LLM の応答に文がありません。' unless text.is_a?(String) # 開発者向け

      text.lines.map(&:strip).reject(&:empty?)
    rescue JSON::ParserError => e
      raise RequestFailedError, "LLM の応答が読めません: #{e.class}" # 開発者向け
    end
  end
end
