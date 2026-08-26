# frozen_string_literal: true

module Generation
  # コピースペースの構図規定の中身です（requirements.md 4.1 の 4）。
  #
  # 中身は `config/copy_space_rules.yml` にあります。**実装の中に埋め込みません。**
  # そのままプロンプトへ入る英文ですので、テストから中身を確かめられる形にします。
  #
  # **中身を検めます。** 位置ごとに 4 つの役割（余白・被写体・視線誘導・
  # 静けさ）がそろっていること、値がそのままプロンプトへ入れられる英文で
  # あることを確かめます。欠けたまま通すと、コピースペースの指定を欠いた案が
  # 出ます（requirements.md 4.2 が禁じています）。
  class CopySpaceRules
    # 定義が読めない、または内容が足りない場合に投げます。
    class InvalidDefinitionError < StandardError; end

    # 定義されていないコピースペース位置を渡された場合に投げます。
    class UnknownPositionError < StandardError; end

    # 定義されていないアスペクト比を渡された場合に投げます。
    class UnknownAspectRatioError < StandardError; end

    DEFINITION_PATH = 'config/copy_space_rules.yml'
    POSITIONS_KEY = 'positions'
    ASPECT_RATIOS_KEY = 'aspect_ratios'

    # 位置ごとに必ず持つ役割です。**順序が指示の並び順になります。**
    ROLES = %w[reserved subject gaze restraint].freeze

    class << self
      # その位置の指示を、役割の順に返します。
      # @return [Array<String>]
      def instructions_for(position)
        rule = positions.fetch(position) do
          raise UnknownPositionError,
                "定義されていないコピースペース位置です: #{position.inspect}" # 開発者向け
        end

        ROLES.map { |role| rule.fetch(role) }
      end

      # そのアスペクト比の構図の言い方を返します。
      # @return [String]
      def aspect_ratio_instruction(aspect_ratio)
        aspect_ratios.fetch(aspect_ratio) do
          raise UnknownAspectRatioError,
                "定義されていないアスペクト比です: #{aspect_ratio.inspect}" # 開発者向け
        end
      end

      # 定義されている位置です。
      def positions
        definition[POSITIONS_KEY]
      end

      # 定義されているアスペクト比です。
      def aspect_ratios
        definition[ASPECT_RATIOS_KEY]
      end

      # テストから読み直せるようにします。**本番の経路では使いません。**
      def reset!
        @definition = nil
      end

      private

      def definition
        @definition ||= load_definition
      end

      def load_definition
        loaded = read_definition
        positions = loaded[POSITIONS_KEY]
        ratios = loaded[ASPECT_RATIOS_KEY]
        ensure_positions!(positions)
        ensure_ratios!(ratios)

        { POSITIONS_KEY => positions.freeze, ASPECT_RATIOS_KEY => ratios.freeze }.freeze
      end

      def read_definition
        loaded = YAML.safe_load_file(Rails.root.join(DEFINITION_PATH))
        return loaded if loaded.is_a?(Hash)

        raise InvalidDefinitionError,
              "コピースペースの定義が読めません: #{DEFINITION_PATH}" # 開発者向け
      rescue Errno::ENOENT, Psych::SyntaxError => e
        raise InvalidDefinitionError,
              "コピースペースの定義を読み込めません: #{DEFINITION_PATH} (#{e.class})" # 開発者向け
      end

      # **仕様が定める 3 つの位置がすべてそろっていることを求めます。**
      # 欠けた位置を指定されると、コピースペースの指定を欠いた案が出ます。
      def ensure_positions!(positions)
        unless positions.is_a?(Hash) &&
               InputChoices::COPY_SPACE_POSITIONS.all? { |name| positions.key?(name) }
          raise InvalidDefinitionError,
                "コピースペースの位置の定義が足りません: #{DEFINITION_PATH}" # 開発者向け
        end

        positions.each { |name, rule| ensure_roles!(name, rule) }
      end

      def ensure_roles!(name, rule)
        unless rule.is_a?(Hash)
          raise InvalidDefinitionError,
                "コピースペースの位置の定義が連想配列ではありません: #{name}" # 開発者向け
        end

        ROLES.each { |role| ensure_text!("#{name}.#{role}", rule[role]) }
      end

      def ensure_ratios!(ratios)
        unless ratios.is_a?(Hash) &&
               InputChoices::ASPECT_RATIOS.all? { |name| ratios.key?(name) }
          raise InvalidDefinitionError,
                "アスペクト比の定義が足りません: #{DEFINITION_PATH}" # 開発者向け
        end

        ratios.each { |name, value| ensure_text!(name, value) }
      end

      # **そのままプロンプトへ入れられる英文であることを求めます。**
      # 記号や数値だけを書くと、生成モデルへ意味をなさない語が渡ります。
      def ensure_text!(where, value)
        return if value.is_a?(String) && !value.strip.empty?

        raise InvalidDefinitionError,
              "コピースペースの指示が英文ではありません: #{where} (#{value.class})" # 開発者向け
      end
    end
  end
end
