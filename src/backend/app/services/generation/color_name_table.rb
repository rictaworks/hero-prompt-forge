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
                       achromatic_name hues modifiers].freeze

    # 0.0 から 1.0 の数値で持つしきい値です。
    THRESHOLD_KEYS = %w[achromatic_saturation black_lightness white_lightness].freeze

    # 修飾語の定義が必ず持つ鍵です。
    MODIFIER_THRESHOLD_KEYS = %w[deep_lightness pale_lightness muted_saturation].freeze
    MODIFIER_NAME_KEYS = %w[deep_name pale_name muted_name].freeze

    # 色の名前として認める形です。**そのままプロンプトへ入る英単語です。**
    NAME_FORMAT = /\A[a-z]+\z/

    # しきい値の範囲です。
    THRESHOLD_RANGE = (0.0..1.0)

    # 色相の全周です。
    FULL_CIRCLE = 360

    class << self
      # @return [Hash]
      def load(path)
        loaded = read(path)
        ensure_keys!(loaded, path)
        ensure_thresholds!(loaded, path)
        ensure_name!(loaded['achromatic_name'], 'achromatic_name', path)
        ensure_modifiers!(loaded['modifiers'], path)
        ensure_hues!(loaded['hues'], path)

        DeepFreeze.call(loaded)
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

      # **しきい値の中身を確かめます。**
      #
      # 鍵の有無だけを見ると、`achromatic_saturation: 1.0` の 1 文字で
      # **すべての色が `gray`** になります。黒白のしきい値を入れ替えれば、
      # **すべての色が `black`** になります。いずれも例外が出ません。
      # このクラスは「中身を信用しません」と約束しています（PR #151 のレビューより）。
      def ensure_thresholds!(loaded, path)
        THRESHOLD_KEYS.each { |key| ensure_threshold!(loaded[key], key, path) }
        return if loaded['black_lightness'] < loaded['white_lightness']

        raise InvalidDefinitionError,
              "黒と白のしきい値が逆です: black_lightness=#{loaded['black_lightness']} " \
              "white_lightness=#{loaded['white_lightness']} (#{path})" # 開発者向け
      end

      def ensure_threshold!(value, where, path)
        return if value.is_a?(Numeric) && THRESHOLD_RANGE.cover?(value)

        raise InvalidDefinitionError,
              "しきい値が 0.0 から 1.0 の数値ではありません: #{where} (#{path})" # 開発者向け
      end

      # **色の名前が英単語であることを確かめます。**
      #
      # 空文字を入れると、色の指示から色が消えます。日本語を入れると、
      # そのまま生成モデルへ渡ります。
      def ensure_name!(value, where, path)
        return if value.is_a?(String) && value.match?(NAME_FORMAT)

        raise InvalidDefinitionError,
              "色の名前が英単語ではありません: #{where} (#{path})" # 開発者向け
      end

      # **修飾語の定義を確かめます。**
      def ensure_modifiers!(modifiers, path)
        unless modifiers.is_a?(Hash)
          raise InvalidDefinitionError, "修飾語の定義がありません: #{path}" # 開発者向け
        end

        MODIFIER_THRESHOLD_KEYS.each do |key|
          ensure_threshold!(modifiers[key], "modifiers.#{key}", path)
        end
        MODIFIER_NAME_KEYS.each { |key| ensure_name!(modifiers[key], "modifiers.#{key}", path) }
        ensure_modifier_order!(modifiers, path)
      end

      # **「深い」と「淡い」の境目が逆だと、すべての色が「深い」になります。**
      def ensure_modifier_order!(modifiers, path)
        return if modifiers['deep_lightness'] < modifiers['pale_lightness']

        raise InvalidDefinitionError,
              "修飾語の明度のしきい値が逆です: deep=#{modifiers['deep_lightness']} " \
              "pale=#{modifiers['pale_lightness']} (#{path})" # 開発者向け
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
          range['name'].is_a?(String) && range['name'].match?(NAME_FORMAT)
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
