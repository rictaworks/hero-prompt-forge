# frozen_string_literal: true

# 規則辞書の初期の内容です。
#
# 中身は `config/rule_dictionary/initial.yml` にあります。**実装の中に
# 埋め込みません。** 初期データは、この製品の中核となる価値（AI っぽさを
# 設計段階で外すこと）を担います。埋め込むと、中身が仕様どおりかを
# テストから確かめられません。
#
# `db/seeds.rb` とテストの両方が、ここを通して同じ内容を読みます。
class InitialRuleDictionary
  # 定義ファイルが読めない、または内容が足りない場合に投げます。
  class InvalidDefinitionError < StandardError; end

  DEFINITION_PATH = 'config/rule_dictionary/initial.yml'

  # 定義に必ずある鍵です。
  REQUIRED_KEYS = %w[version anti_ai_rules style_spec_rules industry_defaults].freeze

  class << self
    # 定義を読み込みます。壊れていれば、その場で失敗させます。
    # @return [Hash]
    def definition(path: DEFINITION_PATH)
      loaded = load_file(path)
      ensure_definition!(path, loaded)

      loaded
    end

    def version(path: DEFINITION_PATH)
      definition(path: path).fetch('version')
    end

    def anti_ai_rules(path: DEFINITION_PATH)
      definition(path: path).fetch('anti_ai_rules')
    end

    def style_spec_rules(path: DEFINITION_PATH)
      definition(path: path).fetch('style_spec_rules')
    end

    def industry_defaults(path: DEFINITION_PATH)
      definition(path: path).fetch('industry_defaults')
    end

    private

    def load_file(path)
      YAML.safe_load_file(Rails.root.join(path))
    rescue Errno::ENOENT, Psych::SyntaxError => e
      raise InvalidDefinitionError,
            "初期の規則辞書の定義を読み込めません: #{path} (#{e.class})" # 開発者向け
    end

    def ensure_definition!(path, loaded)
      unless loaded.is_a?(Hash)
        raise InvalidDefinitionError,
              "初期の規則辞書の定義が読めません: #{path}" # 開発者向け
      end

      missing = REQUIRED_KEYS.reject { |key| loaded[key].present? }
      return if missing.empty?

      raise InvalidDefinitionError,
            "初期の規則辞書の定義が足りません: #{missing.join(', ')} (#{path})" # 開発者向け
    end
  end
end
