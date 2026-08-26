# frozen_string_literal: true

module Generation
  # 色コードから色の名前を求めます（requirements.md 4.1 の 5）。
  #
  # **生成モデルへ色コードを渡しません。** `#0E7C7B` と書いても、モデルは色として
  # 受け取りません。**色の名前で渡します。**
  #
  # 名前は色相・彩度・明度から機械的に決めます。**名前を一覧で持ちません。**
  # 色は無数にあり、並べ切れないためです。範囲は `config/color_names.yml` にあります。
  class ColorName
    # 定義が読めない、または内容が足りない場合に投げます。
    class InvalidDefinitionError < StandardError; end

    # 色コードの形が違う場合に投げます。
    class InvalidColorError < StandardError; end

    DEFINITION_PATH = 'config/color_names.yml'

    class << self
      # 色コードから名前を求めます。
      # @param color [String] `#RRGGBB` の形です
      # @return [String] 英語の色名です
      def of(color)
        red, green, blue = channels(color)
        hue, saturation, lightness = to_hsl(red, green, blue)

        return achromatic_name(lightness) if achromatic?(saturation, lightness)

        hue_name(hue)
      end

      # テストから読み直せるようにします。**本番の経路では使いません。**
      def reset!
        @definition = nil
      end

      private

      def channels(color)
        unless color.is_a?(String) && color.match?(InputChoices::BRAND_COLOR_FORMAT)
          raise InvalidColorError, "色コードの形が違います: #{color.inspect}" # 開発者向け
        end

        [color[1, 2], color[3, 2], color[5, 2]].map { |part| part.to_i(16) / 255.0 }
      end

      # 色相（0-360）・彩度（0-1）・明度（0-1）を求めます。
      def to_hsl(red, green, blue)
        max = [red, green, blue].max
        min = [red, green, blue].min
        lightness = (max + min) / 2.0
        span = max - min
        return [0.0, 0.0, lightness] if span.zero?

        [hue_of(red, green, blue, max, span), saturation_of(span, lightness), lightness]
      end

      def saturation_of(span, lightness)
        lightness > 0.5 ? span / (2.0 - (2 * lightness)) : span / (2.0 * lightness)
      end

      def hue_of(red, green, blue, max, span)
        degrees = case max
                  when red then ((green - blue) / span) % 6
                  when green then ((blue - red) / span) + 2
                  else ((red - green) / span) + 4
                  end

        (degrees * 60) % 360
      end

      # **色みが無い色を、色相で名づけません。**
      # 灰色に近い色へ「青」「緑」と名づけると、指示が実際の色から離れます。
      def achromatic?(saturation, lightness)
        saturation <= definition.fetch('achromatic_saturation') ||
          lightness <= definition.fetch('black_lightness') ||
          lightness >= definition.fetch('white_lightness')
      end

      # 黒に近い色・白に近い色は、そのまま黒・白と呼びます。
      def achromatic_name(lightness)
        return 'black' if lightness <= definition.fetch('black_lightness')
        return 'white' if lightness >= definition.fetch('white_lightness')

        definition.fetch('achromatic_name')
      end

      def hue_name(hue)
        found = definition.fetch('hues').find { |range| hue >= range['from'] && hue < range['to'] }
        return found['name'] if found

        raise InvalidDefinitionError,
              "色相の範囲に隙間があります: #{hue}" # 開発者向け
      end

      def definition
        @definition ||= ColorNameTable.load(DEFINITION_PATH)
      end
    end
  end
end
