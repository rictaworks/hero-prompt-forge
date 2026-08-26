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

    # 待つ秒数の項目です。
    TIMEOUT_KEYS = %w[
      open_timeout_seconds read_timeout_seconds write_timeout_seconds
    ].freeze

    # 得点の取りうる範囲です。
    SCORE_RANGE = (0.0..1.0)

    class << self
      # @return [Hash]
      def load(path: PATH)
        values = read(path)
        ensure_complete!(values, path)
        ensure_types!(values, path)

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

      # **型と範囲まで検めます**（PR #168 のレビューより）。
      #
      # 得点の下限を文字列で書くと、比べる段で `ArgumentError` になり、
      # **500 として利用者へ届きます。** 設定の誤りは、設定の誤りとして
      # その場で失敗させます。
      def ensure_types!(values, path)
        ensure_score!(values, path)
        ensure_timeouts!(values, path)
        ensure_action!(values, path)
        ensure_endpoint!(values, path)
      end

      def ensure_score!(values, path)
        score = values.fetch('minimum_score')
        return if score.is_a?(Numeric) && SCORE_RANGE.cover?(score)

        raise InvalidSettingsError,
              "得点の下限が 0.0〜1.0 の数値ではありません: #{path} -> #{score.inspect}" # 開発者向け
      end

      def ensure_timeouts!(values, path)
        wrong = TIMEOUT_KEYS.reject do |key|
          value = values.fetch(key)
          value.is_a?(Numeric) && value.positive?
        end
        return if wrong.empty?

        raise InvalidSettingsError,
              "待つ秒数が正の数ではありません: #{path} -> #{wrong.inspect}" # 開発者向け
      end

      def ensure_action!(values, path)
        return if values.fetch('expected_action').to_s.present?

        raise InvalidSettingsError, "行動の名前が空です: #{path}" # 開発者向け
      end

      def ensure_endpoint!(values, path)
        endpoint = values.fetch('verification_endpoint').to_s
        return if endpoint.start_with?('https://')

        raise InvalidSettingsError,
              "照合先が https ではありません: #{path} -> #{endpoint.inspect}" # 開発者向け
      end
    end
  end
end
