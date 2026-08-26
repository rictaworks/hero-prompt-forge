# frozen_string_literal: true

module Generation
  # バリエーション3案の規則の読み込みと検めです（requirements.md 4.1 の 8）。
  #
  # **規則は人が編集するデータです。中身を信用しません。**
  # 構図が 1 つ欠けるだけで、3 案がそろわなくなります。**4.2 は 3 案を求めます。**
  #
  # **読み込みは 1 度だけです。** 生成のたびに YAML を読むと、1 件の生成で
  # 何度も同じファイルを開きます。
  class VariationRules
    # 規則が読めない、または内容が足りない場合に投げます。
    class InvalidDefinitionError < StandardError; end

    DEFINITION_PATH = 'config/variation_rules.yml'

    ORDER_KEY = 'order'
    COMPOSITIONS_KEY = 'compositions'
    COPY_SPACE_CONFLICTS_KEY = 'copy_space_conflicts'
    FOCUS_KEY = 'focus'
    DROPS_KEY = 'drops'

    # **仕様が求める案の数です。**
    REQUIRED_COUNT = 3

    # **そのままプロンプトへ入れられる英文の形です。**
    ENGLISH_TEXT_FORMAT = /\A[\x20-\x7E]+\z/

    # **打ち消しの言い回しです。** かえってその要素を呼び込みます。
    NEGATION_FORMAT = /\b(?:no|not|never|without|avoid|avoiding|free of|lacking)\b/i

    class << self
      # @return [Hash]
      def load(path: DEFINITION_PATH)
        @definition ||= {}
        @definition[path] ||= build(path)
      end

      # テストから読み直せるようにします。**本番の経路では使いません。**
      def reset!
        @definition = nil
      end

      private

      def build(path)
        loaded = read(path)
        ensure_order!(loaded, path)
        ensure_conflicts!(loaded, path)
        ensure_compositions!(loaded, path)

        deep_freeze(loaded)
      end

      # **余白と衝突する言い回しの一覧を検めます。**
      def ensure_conflicts!(loaded, path)
        conflicts = loaded[COPY_SPACE_CONFLICTS_KEY]
        return if conflicts.is_a?(Array) && conflicts.any? && conflicts.all?(String)

        raise InvalidDefinitionError,
              "余白と衝突する言い回しの一覧がありません: #{path}" # 開発者向け
      end

      def read(path)
        loaded = YAML.safe_load_file(Rails.root.join(path))
        return loaded if loaded.is_a?(Hash)

        raise InvalidDefinitionError, "展開の規則が読めません: #{path}" # 開発者向け
      rescue Errno::ENOENT, Psych::SyntaxError => e
        raise InvalidDefinitionError,
              "展開の規則を読み込めません: #{path} (#{e.class})" # 開発者向け
      end

      # **必ず 3 案です。** 4.2 は 3 案を求めます。
      def ensure_order!(loaded, path)
        order = loaded[ORDER_KEY]
        return if order.is_a?(Array) && order.size == REQUIRED_COUNT &&
                  order.uniq.size == REQUIRED_COUNT &&
                  order.all?(String)

        raise InvalidDefinitionError,
              "案の順が #{REQUIRED_COUNT} 通りそろっていません: #{path}" # 開発者向け
      end

      def ensure_compositions!(loaded, path)
        compositions = loaded[COMPOSITIONS_KEY]
        unless compositions.is_a?(Hash)
          raise InvalidDefinitionError, "構図の定義がありません: #{path}" # 開発者向け
        end

        loaded[ORDER_KEY].each do |name|
          ensure_composition!(compositions[name], name, path, loaded[COPY_SPACE_CONFLICTS_KEY])
        end
      end

      def ensure_composition!(composition, name, path, conflicts)
        unless composition.is_a?(Hash)
          raise InvalidDefinitionError, "構図の定義がありません: #{name} (#{path})" # 開発者向け
        end

        ensure_text!(composition[FOCUS_KEY], "#{name}.#{FOCUS_KEY}", path)
        ensure_no_copy_space_conflict!(composition[FOCUS_KEY], "#{name}.#{FOCUS_KEY}", path, conflicts)
        ensure_drops!(composition[DROPS_KEY], "#{name}.#{DROPS_KEY}", path)
      end

      # **コピースペースの確保を打ち消す指示を止めます。**
      #
      # 余白の確保は最上位の指定です（requirements.md 4.1 の 5）。
      # 展開の段は余白の段より後に走りますので、`filling the frame` と書くと、
      # あとから来るこの指示が最上位の指定を上書きする読み方ができます。
      def ensure_no_copy_space_conflict!(value, where, path, conflicts)
        matched = conflicts.find { |conflict| value.include?(conflict) }
        return if matched.nil?

        raise InvalidDefinitionError,
              "余白の確保を打ち消す言い回しがあります: #{where} / #{matched} (#{path})" # 開発者向け
      end

      # **外す素材の役割は、名前の一覧で書きます。**
      def ensure_drops!(drops, where, path)
        return if drops.is_a?(Array) && drops.all?(String) && drops.uniq.size == drops.size

        raise InvalidDefinitionError,
              "外す素材の役割の一覧が読めません: #{where} (#{path})" # 開発者向け
      end

      def ensure_text!(value, where, path)
        unless value.is_a?(String) && value.strip.present? &&
               value.match?(ENGLISH_TEXT_FORMAT)
          raise InvalidDefinitionError,
                "構図の指示が英文ではありません: #{where} (#{path})" # 開発者向け
        end

        return unless value.match?(NEGATION_FORMAT)

        raise InvalidDefinitionError,
              "構図の指示に打ち消しの言い回しがあります: #{where} (#{path})" # 開発者向け
      end

      # **入れ子の中まで凍らせます。** 器だけでは、中の連想配列を書き換えられます。
      def deep_freeze(value)
        case value
        when Hash then value.each_value { |item| deep_freeze(item) }.freeze
        when Array then value.each { |item| deep_freeze(item) }.freeze
        else value.freeze
        end
      end
    end
  end
end
