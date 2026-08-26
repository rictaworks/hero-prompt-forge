# frozen_string_literal: true

module BotProtection
  # reCAPTCHA の設定です（`config/recaptcha.yml`）。
  #
  # **実装の中へ値を書きません。** 得点の下限も待ち時間も、運用で変わります。
  # **欠けている項目は、その場で失敗させます。** 既定へ寄せると、
  # 判定が緩んでいても気づけません。
  class Settings
    # 設定が読めない、または項目が欠けている場合に投げます。
    class InvalidSettingsError < StandardError; end

    PATH = 'config/recaptcha.yml'

    REQUIRED = %w[
      verification_endpoint minimum_score expected_action
      open_timeout_seconds read_timeout_seconds write_timeout_seconds
    ].freeze

    class << self
      # @return [Hash]
      def load(path: PATH)
        values = read(path)
        ensure_complete!(values, path)

        values
      end

      private

      def read(path)
        full = Rails.root.join(path)
        raise InvalidSettingsError, "設定がありません: #{path}" unless full.exist? # 開発者向け

        parsed = YAML.safe_load_file(full)
        return parsed if parsed.is_a?(Hash)

        raise InvalidSettingsError, "設定の形が違います: #{path}" # 開発者向け
      end

      def ensure_complete!(values, path)
        missing = REQUIRED - values.keys
        return if missing.empty?

        raise InvalidSettingsError,
              "設定の項目が足りません: #{path} -> #{missing.inspect}" # 開発者向け
      end
    end
  end
end
