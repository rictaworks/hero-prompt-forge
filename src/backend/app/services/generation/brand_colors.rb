# frozen_string_literal: true

module Generation
  # ブランドカラーの検証と正規化です（requirements.md 4.1）。
  #
  # 最大2色まで、6桁の色指定だけを受け取ります。表記の揺れは大文字へ揃えます。
  #
  # **同じ色の重ねがけは、1色として扱わずに誤りとして返します。**
  # 黙って1色に減らすと、利用者が2色を指定したつもりの意図と食い違います。
  class BrandColors
    # 検証の結果です。`reason` があれば誤りです。
    Result = Struct.new(:colors, :reason, keyword_init: true)

    class << self
      # @return [Result]
      def normalize(raw)
        return accepted([]) if raw.nil?
        return rejected(:invalid_type) unless raw.is_a?(Array)

        values = raw.filter_map { |value| trimmed(value) }
        return accepted([]) if values.empty?

        check(values)
      end

      private

      def trimmed(value)
        return value unless value.is_a?(String)

        stripped = value.strip
        stripped.empty? ? nil : stripped
      end

      def check(values)
        return rejected(:invalid_type) unless values.all?(String)
        return rejected(:too_many) if values.size > InputChoices::MAX_BRAND_COLORS
        return rejected(:invalid_format) unless values.all? { |v| v.match?(InputChoices::BRAND_COLOR_FORMAT) }

        upcased = values.map(&:upcase)
        return rejected(:duplicated) if upcased.uniq.size < upcased.size

        accepted(upcased)
      end

      def accepted(colors)
        Result.new(colors: colors, reason: nil)
      end

      def rejected(reason)
        Result.new(colors: [], reason: reason)
      end
    end
  end
end
