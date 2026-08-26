# frozen_string_literal: true

module Generation
  # 色の名前の定義の読み込みと検めです。
  #
  # **定義は人が編集するデータです。中身を信用しません。**
  # 色相の範囲に隙間があると、その色だけ名前が決まらず、生成が止まります。
  class ColorNameTable
    InvalidDefinitionError = ColorName::InvalidDefinitionError

    # 必ずある鍵です。
    REQUIRED_KEYS = %w[achromatic_saturation black_lightness white_lightness
                       achromatic_name hues].freeze

    # 色相の全周です。
    FULL_CIRCLE = 360

    class << self
      # @return [Hash]
      def load(path)
        loaded = read(path)
        ensure_keys!(loaded, path)
        ensure_hues!(loaded['hues'], path)

        loaded.freeze
      end

      private

      def read(path)
        loaded = YAML.safe_load_file(Rails.root.join(path))
        return loaded if loaded.is_a?(Hash)

        raise InvalidDefinitionError, "色の名前の定義が読めません: #{path}" # 開発者向け
      rescue Errno::ENOENT, Psych::SyntaxError => e
        raise InvalidDefinitionError,
              "色の名前の定義を読み込めません: #{path} (#{e.class})" # 開発者向け
      end

      def ensure_keys!(loaded, path)
        missing = REQUIRED_KEYS.reject { |key| loaded.key?(key) }
        return if missing.empty?

        raise InvalidDefinitionError,
              "色の名前の定義が足りません: #{missing.join(', ')} (#{path})" # 開発者向け
      end

      # **色相の範囲が全周を覆っていることを確かめます。**
      # 隙間があると、その色だけ名前が決まらず、生成が止まります。
      # 重なりがあると、先に書いた範囲だけが当たり、後ろの定義が黙って死にます。
      def ensure_hues!(hues, path)
        unless hues.is_a?(Array) && hues.any?
          raise InvalidDefinitionError, "色相の範囲がありません: #{path}" # 開発者向け
        end

        ensure_shape!(hues, path)
        ensure_continuous!(hues, path)
      end

      def ensure_shape!(hues, path)
        return if hues.all? { |range| valid_range?(range) }

        raise InvalidDefinitionError, "色相の範囲の形が違います: #{path}" # 開発者向け
      end

      def valid_range?(range)
        range.is_a?(Hash) &&
          range['from'].is_a?(Numeric) && range['to'].is_a?(Numeric) &&
          range['from'] < range['to'] &&
          range['name'].is_a?(String) && range['name'].match?(/\A[a-z]+\z/)
      end

      def ensure_continuous!(hues, path)
        sorted = hues.sort_by { |range| range['from'] }
        expected = 0
        sorted.each do |range|
          next expected = range['to'] if range['from'] == expected

          raise InvalidDefinitionError,
                "色相の範囲が続いていません: #{expected} から #{range['from']} (#{path})" # 開発者向け
        end
        return if expected == FULL_CIRCLE

        raise InvalidDefinitionError,
              "色相の範囲が全周を覆っていません: #{expected} まで (#{path})" # 開発者向け
      end
    end
  end
end
