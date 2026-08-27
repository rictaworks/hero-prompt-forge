# frozen_string_literal: true

require 'net/http'

module Generation
  # Gemini への呼び出しです（requirements.md 4.1 の 10、issue #52、#160）。
  #
  # **呼び出しは LangChain（Ruby 版 `langchainrb`）を通します**（issue #160）。
  # 仕様の技術スタックが LangChain を挙げています（requirements.md 3）。
  # **モデルの差し替えは、呼び出しの書き方を変えずに設定だけで行えます。**
  #
  # **API キーを環境変数から読みます。** ソースにも設定ファイルにも書きません。
  # **キーが無ければ、その場で失敗させます。** 既定へ寄せると、精緻化を
  # 行ったつもりで行われていない状態になります。
  #
  # **キーを URL へ載せません。** 見出しで送ります。載せる先の上書きは
  # `LangchainGemini` が持ちます。
  #
  # **送るのは、磨く対象の英文と、利用者が選んだ条件だけです。**
  # 認証情報・利用者の識別子・セッションを送りません。
  #
  # **待ち続けません。** 越えたら失敗させ、縮退（issue #53）へ回します。
  #
  # **追跡（LangSmith）を有効にしません。** 有効にすると、磨く対象の英文が
  # 第三者の保管先へ渡ります。**送る内容と保管期間を決めるまで、使いません**
  # （issue #160 の受け入れ条件）。判断は `SPEC/api/README.md` ではなく、
  # プライバシーポリシー（issue #171）の側で扱います。
  class GeminiClient
    # API キーが環境変数にない場合に投げます。
    class MissingApiKeyError < StandardError; end

    # 呼び出しが失敗した場合に投げます。
    class RequestFailedError < StandardError; end

    # API キーを読む環境変数の名前です。
    API_KEY_VARIABLE = 'GEMINI_API_KEY'

    # キーを載せる見出しです。**URL へ載せません。** 記録へ残ります。
    API_KEY_HEADER = LangchainGemini::API_KEY_HEADER

    # 呼び出しの失敗として扱う出来事です。
    #
    # **通信の失敗をすべて受け止めます。** 受け止め漏れがあると、
    # 縮退（issue #53）へ回らず、生成そのものが落ちます
    # （PR #162 のレビューより）。
    #
    # **網を広げすぎません。** `StandardError` で受けると、書き間違い
    # （`NoMethodError`）まで飲み込み、**誤りが記録にも利用者にも現れないまま
    # 消えます**（PR #165 のレビューより）。
    FAILURES = [Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout,
                OpenSSL::SSL::SSLError, SocketError, SystemCallError, IOError,
                JSON::ParserError].freeze

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
      traced(lines) { parse(completion(instruction, lines)) }
    end

    private

    attr_reader :settings

    def traced(lines, &)
      Trace.step('generation.llm_requested',
                 model: settings.fetch('model'), lines: lines.size,
                 via: 'langchain', &)
    end

    def api_key
      key = ENV.fetch(API_KEY_VARIABLE, nil)
      return key if key.present?

      raise MissingApiKeyError,
            "環境変数 #{API_KEY_VARIABLE} が設定されていません。" # 開発者向け
    end

    def model
      LangchainGemini.new(
        api_key: api_key,
        timeouts: { open: settings.fetch('open_timeout_seconds'),
                    read: settings.fetch('read_timeout_seconds'),
                    write: settings.fetch('write_timeout_seconds') },
        default_options: { chat_model: settings.fetch('model'),
                           temperature: settings.fetch('temperature') }
      )
    end

    # **送るのは、指示文と磨く対象の英文だけです。**
    #
    # **失敗の中身を持ち越しません。** `langchainrb` は、応答に文が無いときに
    # 応答そのものを添えて投げます。**種別だけを残して包み直します。**
    def completion(instruction, lines)
      model.chat(messages: [{ role: 'user', parts: [{ text: "#{instruction}\n\n#{lines.join("\n")}" }] }],
                 max_tokens: settings.fetch('max_output_tokens'))
           .chat_completion
    rescue *FAILURES => e
      raise RequestFailedError, "LLM の呼び出しが失敗しました: #{e.class}" # 開発者向け
    rescue StandardError => e
      # **`langchainrb` は、応答に文が無いときに素の `StandardError` を、
      # 応答そのものを添えて投げます。** そのまま外へ出すと、応答の中身が
      # 記録へ流れます。**種別だけを残して包み直します。**
      #
      # **素の `StandardError` だけを包みます。** 書き間違いは、そのまま外へ出します。
      raise e unless e.instance_of?(StandardError)

      raise RequestFailedError, 'LLM の応答が読めません。' # 開発者向け
    end

    # **返ってきた形が違えば、その場で失敗させます。**
    def parse(text)
      raise RequestFailedError, 'LLM の応答に文がありません。' unless text.is_a?(String) # 開発者向け

      text.lines.map(&:strip).reject(&:empty?)
    end
  end
end
