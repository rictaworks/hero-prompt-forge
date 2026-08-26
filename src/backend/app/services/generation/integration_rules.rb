# frozen_string_literal: true

module Generation
  # 統合の規則の読み込みと検めです（requirements.md 4.1 の 5）。
  #
  # **規則は人が編集するデータです。中身を信用しません。**
  # トーンの装飾が 1 つ欠けるだけで、その業種の生成が止まります。
  class IntegrationRules
    InvalidDefinitionError = ConflictResolver::InvalidDefinitionError

    DEFINITION_PATH = 'config/integration_rules.yml'
    BRAND_COLOR_KEY = 'brand_color'
    TONES_KEY = 'tones'
    TONE_RESTRAINT_KEY = 'tone_restraint'

    # ブランドカラーの統合の強さです。**3 つとも必ずあります。**
    BRAND_COLOR_STRENGTHS = %w[accent secondary_accent weakened].freeze

    # 色の名前を差し込む場所です。
    COLOR_PLACEHOLDER = '%<color>s'

    class << self
      # @return [Hash]
      def load(path: DEFINITION_PATH)
        loaded = read(path)
        ensure_brand_color!(loaded[BRAND_COLOR_KEY], path)
        ensure_tones!(loaded[TONES_KEY], path)
        ensure_text!(loaded[TONE_RESTRAINT_KEY], TONE_RESTRAINT_KEY, path)

        loaded.freeze
      end

      private

      def read(path)
        loaded = YAML.safe_load_file(Rails.root.join(path))
        return loaded if loaded.is_a?(Hash)

        raise InvalidDefinitionError, "統合の規則が読めません: #{path}" # 開発者向け
      rescue Errno::ENOENT, Psych::SyntaxError => e
        raise InvalidDefinitionError,
              "統合の規則を読み込めません: #{path} (#{e.class})" # 開発者向け
      end

      # **3 つの強さがすべてそろっていることを求めます。**
      # 弱めた形が欠けると、アンチAIルック規則に当たったブランドカラーを
      # 落とすほかなくなります。4.1 の 5 は「弱める」と定めています。
      def ensure_brand_color!(rule, path)
        unless rule.is_a?(Hash)
          raise InvalidDefinitionError,
                "ブランドカラーの統合の規則がありません: #{path}" # 開発者向け
        end

        BRAND_COLOR_STRENGTHS.each do |strength|
          ensure_text!(rule[strength], "#{BRAND_COLOR_KEY}.#{strength}", path)
          ensure_placeholder!(rule[strength], "#{BRAND_COLOR_KEY}.#{strength}", path)
        end
      end

      # **仕様が定めるトーンをすべて持つことを求めます。**
      # 1 つ欠けると、その業種の生成が止まります。
      def ensure_tones!(tones, path)
        unless tones.is_a?(Hash)
          raise InvalidDefinitionError, "トーンの装飾がありません: #{path}" # 開発者向け
        end

        missing = InputChoices::BRAND_TONES - tones.keys
        unless missing.empty?
          raise InvalidDefinitionError,
                "トーンの装飾が足りません: #{missing.join(', ')} (#{path})" # 開発者向け
        end

        tones.each { |tone, text| ensure_text!(text, "#{TONES_KEY}.#{tone}", path) }
      end

      # **そのままプロンプトへ入れられる英文であることを求めます。**
      def ensure_text!(value, where, path)
        return if value.is_a?(String) && value.strip.present?

        raise InvalidDefinitionError,
              "統合の規則が英文ではありません: #{where} (#{path})" # 開発者向け
      end

      # **色を差し込む場所があることを求めます。**
      # 無いと、どの色を指しているのか分からない指示になります。
      def ensure_placeholder!(value, where, path)
        return if value.include?(COLOR_PLACEHOLDER)

        raise InvalidDefinitionError,
              "色を差し込む場所がありません: #{where} (#{path})" # 開発者向け
      end
    end
  end
end
