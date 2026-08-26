# frozen_string_literal: true

module Generation
  # LLM による精緻化の設定の読み込みと検めです（requirements.md 4.1 の 10、8）。
  #
  # **設定は人が編集するデータです。中身を信用しません。**
  # 呼び出し先が空のまま通すと、生成のたびに落ちます。
  #
  # **API キーはここに含めません。** 環境変数から読みます。
  class LlmSettings
    # 設定が読めない、または内容が足りない場合に投げます。
    class InvalidDefinitionError < StandardError; end

    DEFINITION_PATH = 'config/llm.yml'

    # 必ずある鍵です。
    TEXT_KEYS = %w[model endpoint instruction].freeze
    NUMBER_KEYS = %w[open_timeout_seconds read_timeout_seconds write_timeout_seconds
                     max_output_tokens].freeze

    # 呼び出し先として認める形です。**暗号化された通信だけを認めます。**
    ENDPOINT_FORMAT = %r{\Ahttps://[^\s]+\z}

    class << self
      # @return [Hash]
      def load(path: DEFINITION_PATH)
        @definition ||= {}
        @definition[path] ||= build(path)
      end

      # テストから読み直せるようにします。
      def reset!
        @definition = nil
      end

      private

      def build(path)
        loaded = read(path)
        TEXT_KEYS.each { |key| ensure_text!(loaded[key], key, path) }
        NUMBER_KEYS.each { |key| ensure_number!(loaded[key], key, path) }
        ensure_endpoint!(loaded['endpoint'], path)
        ensure_temperature!(loaded['temperature'], path)

        DeepFreeze.call(loaded)
      end

      def read(path)
        loaded = YAML.safe_load_file(Rails.root.join(path))
        return loaded if loaded.is_a?(Hash)

        raise InvalidDefinitionError, "LLM の設定が読めません: #{path}" # 開発者向け
      rescue Errno::ENOENT, Psych::SyntaxError => e
        raise InvalidDefinitionError,
              "LLM の設定を読み込めません: #{path} (#{e.class})" # 開発者向け
      end

      def ensure_text!(value, key, path)
        return if value.is_a?(String) && value.strip.present?

        raise InvalidDefinitionError, "LLM の設定が足りません: #{key} (#{path})" # 開発者向け
      end

      def ensure_number!(value, key, path)
        return if value.is_a?(Numeric) && value.positive?

        raise InvalidDefinitionError,
              "LLM の設定が正の数ではありません: #{key} (#{path})" # 開発者向け
      end

      # **暗号化されていない呼び出し先を認めません。**
      # 平文で送ると、指示の中身が経路上で読み取れます。
      def ensure_endpoint!(endpoint, path)
        return if endpoint.match?(ENDPOINT_FORMAT)

        raise InvalidDefinitionError,
              "呼び出し先が暗号化された通信ではありません: #{path}" # 開発者向け
      end

      def ensure_temperature!(value, path)
        return if value.is_a?(Numeric) && value >= 0 && value <= 2

        raise InvalidDefinitionError,
              "ばらつきの大きさが 0 から 2 の数値ではありません: #{path}" # 開発者向け
      end
    end
  end
end
