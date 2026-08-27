# frozen_string_literal: true

module Adapters
  # 生成モデルごとの記法の読み込みと検めです（requirements.md 4.1 の 7、11）。
  #
  # **記法は人が編集するデータです。中身を信用しません。**
  # 区切りが 1 つ欠けるだけで、そのモデルの整形が止まります。
  #
  # **読み込みは 1 度だけです。** 生成のたびに YAML を読むと、1 件の生成で
  # 何度も同じファイルを開きます。
  class AdapterRules
    # 記法が読めない、または内容が足りない場合に投げます。
    class InvalidDefinitionError < StandardError; end

    DEFINITION_PATH = 'config/model_adapters.yml'

    # **そのままプロンプトへ入れられる英文の形です。**
    # 印字できる ASCII だけを認めます。日本語が混ざると、そのまま生成モデルへ
    # 渡ります。
    ENGLISH_TEXT_FORMAT = /\A[\x20-\x7E]+\z/

    class << self
      # 生成モデルの記法を返します。
      # @return [Hash]
      def for(model_key, keys:)
        rules = all.fetch(model_key) do
          raise InvalidDefinitionError, "記法がありません: #{model_key}" # 開発者向け
        end
        ensure_keys!(rules, model_key, keys)

        rules
      end

      # テストから読み直せるようにします。**本番の経路では使いません。**
      def reset!
        @all = nil
      end

      private

      def all
        @all ||= deep_freeze(read(DEFINITION_PATH))
      end

      # **別名（アンカー）を許します。** 自然文で書くモデルは、役割ごとの述語を
      # 同じ内容で持ちます。書き写すと、片方だけを直したときに食い違います。
      def read(path)
        loaded = YAML.safe_load_file(Rails.root.join(path), aliases: true)
        return loaded if loaded.is_a?(Hash)

        raise InvalidDefinitionError, "記法が読めません: #{path}" # 開発者向け
      rescue Errno::ENOENT, Psych::SyntaxError => e
        raise InvalidDefinitionError,
              "記法を読み込めません: #{path} (#{e.class})" # 開発者向け
      end

      # **必要な鍵がすべてそろい、英文であることを求めます。**
      def ensure_keys!(rules, model_key, keys)
        unless rules.is_a?(Hash)
          raise InvalidDefinitionError, "記法の形が違います: #{model_key}" # 開発者向け
        end

        keys.each { |key| ensure_text!(rules[key], "#{model_key}.#{key}") }
      end

      def ensure_text!(value, where)
        return if value.is_a?(String) && value.match?(ENGLISH_TEXT_FORMAT)

        raise InvalidDefinitionError, "記法が英文ではありません: #{where}" # 開発者向け
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
