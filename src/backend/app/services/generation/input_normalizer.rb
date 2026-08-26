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
    include InputChoices

    # 入力に誤りがある場合に投げます。誤りは項目ごとにまとめて持ちます。
    # 文言はこの層で作りません。呼び出す側が項目と理由から組み立てます。
    class InvalidInputError < StandardError
      attr_reader :errors

      def initialize(errors)
        @errors = errors
        super("入力に誤りがあります: #{errors.inspect}") # 開発者向け
      end
    end

    # 規則辞書が渡されていない場合に投げます。
    class MissingDictionaryError < StandardError; end

    # 規則辞書の内容が選択肢から外れている場合に投げます。
    class InvalidDictionaryError < StandardError; end

    def initialize(dictionary:)
      raise MissingDictionaryError, '規則辞書がありません。' if dictionary.nil? # 開発者向け

      @dictionary = dictionary
      @errors = []
    end

    # 正規化した入力を返します。誤りがあれば InvalidInputError です。
    # @return [Hash]
    def call(raw)
      input = take_known(raw)
      @errors = []

      normalized = required_part(input).merge(optional_part(input))
      normalized[:brand_tone] = requested_tone(input)
      # 入力の誤りを先に返します。あとにすると、規則辞書の不備が
      # 利用者の入力の誤りを隠します。
      raise InvalidInputError, @errors if @errors.any?

      normalized[:brand_tone] ||= default_tone(normalized[:industry])
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

    # 想定した項目だけを取り出します。**先に絞ってから記号へ直します。**
    # 届いたすべての鍵を先に直すと、鍵の型が想定外だった場合に、項目名を
    # 添えられない失敗になります。
    def take_known(raw)
      raise InvalidInputError, [{ field: :root, reason: :invalid_type }] unless raw.respond_to?(:[])

      KNOWN_FIELDS.index_with { |field| raw[field].nil? ? raw[field.to_s] : raw[field] }
    end

    # 文字列として扱える値かどうかを確かめます。
    def string_like?(value)
      value.is_a?(String)
    end

    # 文字列として受け取る項目の値を整えます。文字列でなければ、項目名を
    # 添えた誤りとして集めます。推測して文字列へ直しません。
    def presence(input, field)
      value = input[field]
      return nil if value.nil?
      return add_error(field, :invalid_type) unless string_like?(value)

      stripped = value.strip
      stripped.empty? ? nil : stripped
    end

    def add_error(field, reason)
      @errors << { field: field, reason: reason }
      nil
    end

    def required_choice(input, field, choices)
      return nil if error_for?(field)

      value = presence(input, field)
      return nil if error_for?(field)
      return add_error(field, :missing) if value.nil?
      return add_error(field, :unknown_value) unless choices.include?(value)

      value
    end

    def optional_choice(input, field, choices, default)
      value = presence(input, field)
      return nil if error_for?(field)
      return default if value.nil?
      return add_error(field, :unknown_value) unless choices.include?(value)

      value
    end

    def error_for?(field)
      @errors.any? { |error| error[:field] == field }
    end

    # 利用者が指定したトーンです。指定が無ければ空を返します。
    def requested_tone(input)
      value = presence(input, :brand_tone)
      return nil if error_for?(:brand_tone) || value.nil?
      return add_error(:brand_tone, :unknown_value) unless BRAND_TONES.include?(value)

      value
    end

    # 業種ごとの標準トーンです。規則辞書から引きます。
    #
    # 定義が無ければ辞書の不備です。推測せず失敗させます。**引いた値も
    # 選択肢に照らします。** 辞書は管理画面から編集できるようになるため、
    # 選べない値が入ったまま先へ進むと、以降の規則適用が想定しない値を
    # 受け取ります。
    def default_tone(industry)
      tone = dictionary.defaults_for(industry).fetch('tone') do
        raise KeyError, "業種の標準トーンがありません: #{industry.inspect}" # 開発者向け
      end

      unless BRAND_TONES.include?(tone)
        raise InvalidDictionaryError,
              "規則辞書の標準トーンが選択肢の外です: #{industry.inspect} -> #{tone.inspect}" # 開発者向け
      end

      tone
    end

    def service_summary(input)
      value = presence(input, :service_summary)
      return nil if error_for?(:service_summary) || value.nil?
      return add_error(:service_summary, :too_long) if value.length > MAX_SERVICE_SUMMARY_LENGTH

      value
    end

    # ブランドカラーです。検証と正規化は BrandColors が持ちます。
    def brand_colors(input)
      result = BrandColors.normalize(input[:brand_colors])
      return add_error(:brand_colors, result.reason) if result.reason

      result.colors
    end
  end
end
