# frozen_string_literal: true

module Generation
  # 読み込んだ設定を、入れ子の中まで凍らせます。
  #
  # **器だけを凍らせても足りません。** 中の連想配列や配列は書き換えられ、
  # 読み込み時に行った検めが意味を失います。設定は起動から終了まで
  # 同じ内容であることを前提に組み立てていますので、途中で変わると、
  # どの値で生成したのかを追えなくなります。
  module DeepFreeze
    module_function

    # @return [Object] 渡された値そのものを、凍らせて返します
    def call(value)
      case value
      when Hash then value.each_value { |item| call(item) }.freeze
      when Array then value.each { |item| call(item) }.freeze
      else value.freeze
      end
    end
  end
end
