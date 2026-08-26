# frozen_string_literal: true

module Generation
  # 入力の検証と正規化です（requirements.md 4.1 の 1）。
  #
  # 必須の3項目（業種・スタイル系統・生成モデル）がそろっているかを確かめ、
  # 任意の項目は既定値で補います。トーンは業種ごとの標準を規則辞書から引きます。
  #
  # **推測で補いません。** 選べない値を受け取ったら、その場で失敗させます。
  # 曖昧なまま先へ進めると、規則の適用も出力も静かにずれます。
  class InputNormalizer
    # 入力に誤りがある場合に投げます。誤りは項目ごとにまとめて持ちます。
    # 文言はこの層で作りません。呼び出す側が項目と理由から組み立てます。
    class InvalidInputError < StandardError
      attr_reader :errors

      def initialize(errors)
        @errors = errors
        super("入力に誤りがあります: #{errors.inspect}") # 開発者向け
      end
    end

    # 選べる値です。requirements.md 4.1 の選択肢に対応します。
    INDUSTRIES = %w[
      saas restaurant medical education real_estate
      manufacturing professional_services ecommerce beauty other
    ].freeze
    STYLE_FAMILIES = %w[photoreal illustration three_d abstract].freeze
    TARGET_MODELS = PromptRequest::TARGET_MODELS
    BRAND_TONES = %w[trust advanced warmth premium friendly minimal].freeze
    COPY_SPACE_POSITIONS = %w[left right bottom_center].freeze
    ASPECT_RATIOS = ['16:9', '21:9', '3:2'].freeze

    # 既定値です。
    DEFAULT_COPY_SPACE_POSITION = 'left'
    DEFAULT_ASPECT_RATIO = '16:9'

    # 上限です。
    MAX_BRAND_COLORS = 2
    MAX_SERVICE_SUMMARY_LENGTH = 1000

    BRAND_COLOR_FORMAT = /\A#[0-9a-fA-F]{6}\z/

    def initialize(dictionary:)
      @dictionary = dictionary
      @errors = []
    end

    # 正規化した入力を返します。誤りがあれば InvalidInputError です。
    # @return [Hash]
    def call(raw)
      input = symbolize(raw)
      @errors = []

      normalized = required_part(input).merge(optional_part(input))
      normalized[:brand_tone] = brand_tone(input, normalized[:industry])
      raise InvalidInputError, @errors if @errors.any?

      normalized
    end

    private

    # 欠かせない3項目です。
    def required_part(input)
      {
        industry: required_choice(input, :industry, INDUSTRIES),
        style_family: required_choice(input, :style_family, STYLE_FAMILIES),
        target_model: required_choice(input, :target_model, TARGET_MODELS)
      }
    end

    # 欠けていれば既定値で補う項目です。
    def optional_part(input)
      {
        service_summary: service_summary(input),
        brand_colors: brand_colors(input),
        copy_space_position: optional_choice(input, :copy_space_position,
                                             COPY_SPACE_POSITIONS, DEFAULT_COPY_SPACE_POSITION),
        aspect_ratio: optional_choice(input, :aspect_ratio, ASPECT_RATIOS, DEFAULT_ASPECT_RATIO)
      }
    end

    attr_reader :dictionary

    def symbolize(raw)
      raw.to_h { |key, value| [key.to_sym, value] }
    end

    def presence(value)
      return nil if value.nil?
      return nil if value.respond_to?(:strip) && value.strip.empty?

      value.respond_to?(:strip) ? value.strip : value
    end

    def add_error(field, reason)
      @errors << { field: field, reason: reason }
      nil
    end

    def required_choice(input, field, choices)
      value = presence(input[field])
      return add_error(field, :missing) if value.nil?
      return add_error(field, :unknown_value) unless choices.include?(value)

      value
    end

    def optional_choice(input, field, choices, default)
      value = presence(input[field])
      return default if value.nil?
      return add_error(field, :unknown_value) unless choices.include?(value)

      value
    end

    # トーンは指定が無ければ業種の標準を使います。標準の定義が無ければ
    # 規則辞書の不備です。推測せず KeyError で失敗させます。
    def brand_tone(input, industry)
      value = presence(input[:brand_tone])
      if value
        return add_error(:brand_tone, :unknown_value) unless BRAND_TONES.include?(value)

        return value
      end

      # 業種そのものが誤っている場合は、標準トーンを引けません。
      # 業種の誤りはすでに集めているため、ここでは何も足しません。
      return nil if industry.nil?

      dictionary.defaults_for(industry).fetch('tone') do
        raise KeyError, "業種の標準トーンがありません: #{industry.inspect}" # 開発者向け
      end
    end

    def service_summary(input)
      value = presence(input[:service_summary])
      return nil if value.nil?
      return add_error(:service_summary, :too_long) if value.length > MAX_SERVICE_SUMMARY_LENGTH

      value
    end

    def brand_colors(input)
      values = Array(input[:brand_colors]).filter_map { |value| presence(value) }
      return [] if values.empty?
      return add_error(:brand_colors, :too_many) if values.size > MAX_BRAND_COLORS
      return add_error(:brand_colors, :invalid_format) unless values.all? { |v| v.match?(BRAND_COLOR_FORMAT) }

      values.map(&:upcase)
    end
  end
end
