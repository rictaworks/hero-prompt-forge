# frozen_string_literal: true

module Generation
  # ブランドカラーの検証と正規化です（requirements.md 4.1）。
  #
  # 最大2色まで、6桁の色指定だけを受け取ります。表記の揺れは大文字へ揃えます。
  #
  # **同じ色の重ねがけは、1色として扱わずに誤りとして返します。**
  # 黙って1色に減らすと、利用者が2色を指定したつもりの意図と食い違います。
  #
  # **一方で、空（nil）と空白だけの要素は、未指定として落とします。**
  # 扱いを分けます。空の欄は「指定していない」ことの素直な表れですが、
  # 同じ色を2度書くのは「2色指定したつもり」との食い違いだからです。
  # 上限2色の判定も、落としたあとの件数で行います。
  #
  # **文字として扱えない並びは、誤りとして返します。** そのまま `strip` を
  # 呼ぶと `Encoding::CompatibilityError` になり、項目名も理由も付きません。
  class BrandColors
    # 検証の結果です。`reason` があれば誤りです。
    Result = Struct.new(:colors, :reason, keyword_init: true)

    # 文字として扱えない並びの目印です。落とさずに誤りへ回すために使います。
    INVALID_TEXT = Object.new.freeze

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
        return INVALID_TEXT unless value.valid_encoding?

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
