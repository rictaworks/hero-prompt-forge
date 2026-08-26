# frozen_string_literal: true

module Generation
  # 入力の検証と正規化です（requirements.md 4.1 の 1）。
  #
  # 必須の3項目（業種・スタイル系統・生成モデル）がそろっているかを確かめ、
  # 任意の項目は既定値で補います。トーンは業種ごとの標準を規則辞書から引きます。
  #
  # **推測で補いません。** 選べない値を受け取ったら、その場で失敗させます。
  # 曖昧なまま先へ進めると、規則の適用も出力も静かにずれます。
  #
  # **1つの呼び出しの途中の状態を、この入れ物へ持ちません。** 誤りの一覧を
  # インスタンスへ持つと、1つのインスタンスを複数のスレッドから同時に使った
  # ときに結果が混ざります（issue #133 で実測しました）。1回の呼び出しの状態は
  # Attempt が持ち、呼び出しごとに作り直します。
  class InputNormalizer
    # 選択肢の定義です。**外へ見せる名前を増やさないため、`include` しません。**
    # 呼び出す側と試験は `Generation::InputChoices::` を直接参照します。
    # 参照の経路が 2 通りあると、どちらが正なのかが読めなくなります。

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
    end

    # 正規化した入力を返します。誤りがあれば InvalidInputError です。
    # @return [Hash]
    def call(raw)
      Attempt.new(dictionary: dictionary).call(raw)
    end

    private

    attr_reader :dictionary

    # 1回の呼び出しです。誤りの一覧をここに持ちます。
    #
    # **呼び出しごとに作ります。** 使い回すと、同時に呼ばれたときに誤りが
    # 混ざります。
    class Attempt
      include InputChoices

      def initialize(dictionary:)
        @dictionary = dictionary
        @errors = []
      end

      def call(raw)
        input = take_known(raw)

        normalized = required_part(input).merge(optional_part(input))
        normalized[:brand_tone] = requested_tone(input)
        # 入力の誤りを先に返します。あとにすると、規則辞書の不備が
        # 利用者の入力の誤りを隠します。
        raise InvalidInputError, recorded(@errors) if @errors.any?

        normalized[:brand_tone] ||= default_tone(normalized[:industry])
        normalized
      end

      private

      attr_reader :dictionary

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
                                               COPY_SPACE_POSITIONS,
                                               DEFAULT_COPY_SPACE_POSITION),
          aspect_ratio: optional_choice(input, :aspect_ratio, ASPECT_RATIOS,
                                        DEFAULT_ASPECT_RATIO)
        }
      end

      # 想定した項目だけを取り出します。**先に絞ってから記号へ直します。**
      # 届いたすべての鍵を先に直すと、鍵の型が想定外だった場合に、項目名を
      # 添えられない失敗になります。
      #
      # **「鍵で引ける形か」を、形そのもので見ます。** `[]` を持つかどうかで
      # 見ると、文字列・配列・数値・構造体がいずれも通り抜けます。通り抜けた
      # あとで `raw[:industry]` を呼ぶと、項目名の無い `TypeError` や
      # `NameError` になり、利用者へ理由を返せません（issue #133）。
      def take_known(raw)
        unless raw.is_a?(Hash) || raw.is_a?(ActionController::Parameters)
          raise InvalidInputError, recorded([{ field: :root, reason: :invalid_type }])
        end

        KNOWN_FIELDS.index_with { |field| raw[field].nil? ? raw[field.to_s] : raw[field] }
      end

      # 文字列として受け取る項目の値を整えます。文字列でなければ、項目名を
      # 添えた誤りとして集めます。推測して文字列へ直しません。
      # **文字として扱えない並びも、項目名を添えた誤りにします。**
      # 壊れた並びのまま `strip` を呼ぶと `Encoding::CompatibilityError` になり、
      # 項目名も理由も付きません。issue #133 が直した症状と同じ形です。
      def presence(input, field)
        value = input[field]
        return nil if value.nil?
        return add_error(field, :invalid_type) unless value.is_a?(String)
        return add_error(field, :invalid_type) unless value.valid_encoding?

        stripped = value.strip
        stripped.empty? ? nil : stripped
      end

      def add_error(field, reason)
        @errors << { field: field, reason: reason }
        nil
      end

      def required_choice(input, field, choices)
        choice(input, field, choices) { add_error(field, :missing) }
      end

      def optional_choice(input, field, choices, default)
        choice(input, field, choices) { default }
      end

      # 値を取り出し、選択肢に照らします。欠けていた場合の扱いだけが違います。
      def choice(input, field, choices)
        value = presence(input, field)
        return nil if error_for?(field)
        return yield if value.nil?
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

      # 差し戻した事実を記録へ残します。
      #
      # **残すのは項目名と理由の記号だけです。** 入力そのものには、利用者の
      # サービス概要が入ります。記録は保管期間が長く、閲覧できる範囲も
      # 広くなります。どの項目で落ちたかは、項目名と理由で追えます。
      def recorded(errors)
        Trace.step('generation.input_rejected',
                   fields: errors.map { |error| error[:field] },
                   reasons: errors.map { |error| error[:reason] }) { errors }
      end
    end

    private_constant :Attempt
  end
end
