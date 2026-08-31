# frozen_string_literal: true

require 'net/http'
require 'securerandom'

module Generation
  # LLM 精緻化（Gemini 呼び出し）の記録を LangSmith へ送ります（issue #200）。
  #
  # **送るのは、Gemini へ実際に送るのと同じ内容だけです。** 指示文・磨く対象の
  # 英文・返ってきた英文・成否・所要時間のみで、認証情報・利用者の識別子・
  # セッションは送りません（利用規約 第7条・プライバシーポリシー 第4条）。
  #
  # **本業を止めません。** `Metrics::SideChannel` と同じ考え方で、この持ち場の
  # 失敗を呼び出す側へ投げません。ただし握りつぶさず、記録へ残します。
  #
  # **`LANGSMITH_API_KEY` が無ければ、その場で何もしません。** 開発・テストでは
  # 既定で未設定のため、送信そのものが起きません。
  class LangsmithLogger
    # API キーを読む環境変数の名前です。
    API_KEY_VARIABLE = 'LANGSMITH_API_KEY'

    # プロジェクト名を読む環境変数の名前です。**未設定なら既定の名前を使います。**
    PROJECT_VARIABLE = 'LANGSMITH_PROJECT'
    DEFAULT_PROJECT = 'hero-prompt-forge'

    ENDPOINT = 'https://api.smith.langchain.com/runs'

    # 通信の失敗として扱う出来事です。**`SideChannel` と同じ考え方で、
    # 書き間違い（`NoMethodError` 等）までは受け止めません。**
    FAILURES = [Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout,
                OpenSSL::SSL::SSLError, SocketError, SystemCallError, IOError,
                JSON::ParserError, StandardError].freeze

    # 1 回の呼び出しの素性です。**引数の数を増やさないための入れ物です。**
    Run = Struct.new(:instruction, :lines, :model, :started_at, :finished_at, keyword_init: true)

    class << self
      # API キーが用意されているかどうかを返します。
      def available?
        ENV[API_KEY_VARIABLE].present?
      end

      # 成功した呼び出しを記録します。**失敗しても、呼び出す側へ投げません。**
      def log_success(refined:, **run_attributes)
        return unless available?

        send_run(Run.new(**run_attributes), outputs: { refined: refined }, error: nil)
      end

      # 失敗した呼び出しを記録します。**失敗しても、呼び出す側へ投げません。**
      def log_failure(error:, **run_attributes)
        return unless available?

        send_run(Run.new(**run_attributes), outputs: nil, error: error.message)
      end

      private

      def send_run(run, outputs:, error:)
        post(build_body(run, outputs: outputs, error: error))
      rescue *FAILURES => e
        failed(e)
      end

      def build_body(run, outputs:, error:)
        base(run).merge(outputs: outputs, error: error).compact
      end

      def base(run)
        {
          id: SecureRandom.uuid,
          name: 'gemini_refine',
          run_type: 'llm',
          project_name: ENV.fetch(PROJECT_VARIABLE, DEFAULT_PROJECT),
          inputs: { instruction: run.instruction, lines: run.lines, model: run.model },
          start_time: run.started_at.utc.iso8601(3),
          end_time: run.finished_at.utc.iso8601(3)
        }
      end

      def post(body)
        uri = URI(ENDPOINT)
        request = Net::HTTP::Post.new(uri)
        request['x-api-key'] = ENV.fetch(API_KEY_VARIABLE, nil)
        request['Content-Type'] = 'application/json'
        request.body = body.to_json

        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5) do |http|
          http.request(request)
        end
      end

      # **失敗を残します。** `Metrics::SideChannel#failed` と同じ考え方です。
      def failed(error)
        Rails.logger.warn(
          "[langsmith] record_failed error=#{error.class.name}" # 開発者向け
        )
        nil
      end
    end
  end
end
