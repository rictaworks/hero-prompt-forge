# frozen_string_literal: true

module Generation
  # 禁止入力の検出です（requirements.md 4.1 の 1）。
  #
  # 実在の人物・企業のロゴや商標・第三者の著作物への言及を見つけます。
  # 見つかった場合、生成は行いません。クォータも消費しません。
  # 差し戻しはジョブ投入の前に決まるためです。
  #
  # 検出の規則は `config/forbidden_inputs.yml` にあります。コードへ直書きしません。
  # **検出は代表的な言い回しに限られます。** すべての固有名詞を網羅するものでは
  # ありません。網羅していないことを前提に、見つかったものだけを確実に止めます。
  #
  # 見つかった理由には、種別と見つかった語だけを持たせます。利用者へ見せる文言は
  # この層で作りません。上位の層が種別から組み立てます。
  class ForbiddenDetector
    # 規則の定義に誤りがある場合に投げます。
    class InvalidRuleError < StandardError; end

    RULES_PATH = 'config/forbidden_inputs.yml'

    # 検出の結果です。
    Result = Struct.new(:reasons, keyword_init: true) do
      def forbidden?
        reasons.any?
      end
    end

    # 見つかった理由です。
    Reason = Struct.new(:kind, :matched, keyword_init: true) do
      def to_h
        { kind: kind, matched: matched }
      end
    end

    def initialize(rules: self.class.load_rules)
      @rules = rules
    end

    # 規則を読み込みます。定義が壊れていれば、その場で失敗させます。
    def self.load_rules(path: RULES_PATH)
      loaded = YAML.safe_load_file(Rails.root.join(path))
      rules = loaded.fetch('rules') do
        raise InvalidRuleError, "規則の定義がありません: #{path}" # 開発者向け
      end

      rules.map { |rule| build_rule(rule) }
    end

    def self.build_rule(rule)
      kind = rule.fetch('kind') { raise InvalidRuleError, "種別がありません: #{rule.inspect}" } # 開発者向け
      patterns = rule.fetch('patterns') do
        raise InvalidRuleError, "検出の語がありません: #{kind}" # 開発者向け
      end

      { kind: kind.to_sym, matchers: patterns.map { |pattern| Regexp.new(pattern) } }
    end

    private_class_method :build_rule

    # 入力を調べます。
    # @return [Result]
    def call(service_summary: nil)
      text = service_summary.to_s
      return Result.new(reasons: []) if text.strip.empty?

      Result.new(reasons: reasons_in(text))
    end

    private

    attr_reader :rules

    def reasons_in(text)
      rules.flat_map do |rule|
        rule[:matchers].filter_map do |matcher|
          matched = matcher.match(text)
          Reason.new(kind: rule[:kind], matched: matched[0]) if matched
        end
      end
    end
  end
end
