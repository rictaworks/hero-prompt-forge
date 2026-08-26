# frozen_string_literal: true

# 色相・彩度・明度から色コードを組み立てます。
#
# **色相の全周を掃くために使います。** 一部の色相だけを並べたテストでは、
# 色の名前の定義に空いた隙間を見つけられません。
class HslColor
  # 色相の 1 区画（度）です。
  SECTOR = 60.0

  # 8 ビットの上限です。
  CHANNEL_MAX = 255

  def initialize(hue:, saturation:, lightness:)
    @hue = hue
    @saturation = saturation
    @lightness = lightness
  end

  # @return [String] `#RRGGBB` の形です
  def to_hex
    format('#%<red>02X%<green>02X%<blue>02X', **channels)
  end

  private

  attr_reader :hue, :saturation, :lightness

  def channels
    red, green, blue = rotated.map { |part| ((part + base) * CHANNEL_MAX).round }
    { red: red, green: green, blue: blue }
  end

  def chroma
    (1 - ((2 * lightness) - 1).abs) * saturation
  end

  def second
    chroma * (1 - (((hue / SECTOR) % 2) - 1).abs)
  end

  def base
    lightness - (chroma / 2)
  end

  def rotated
    case hue
    when 0...60 then [chroma, second, 0]
    when 60...120 then [second, chroma, 0]
    when 120...180 then [0, chroma, second]
    when 180...240 then [0, second, chroma]
    when 240...300 then [second, 0, chroma]
    else [chroma, 0, second]
    end
  end
end
