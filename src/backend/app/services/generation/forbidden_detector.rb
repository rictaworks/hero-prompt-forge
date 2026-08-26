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
  # **通してよい文章を止めないことを、検出することと同じくらい重視します。**
  # 「代表取締役社長」「オーナー様」「ロゴ制作」のような普通の言い回しで生成を
  # お断りすると、権利の問題と関係のない利用者が使えなくなります。見送る語を
  # 並べるのではなく、語の形で見分けます（`config/forbidden_inputs.yml` を参照）。
  #
  # 見つかった理由には、種別・見つかった語・直し方の鍵だけを持たせます。利用者へ
  # 見せる文言はこの層で作りません。上位の層が鍵から組み立てます。
  class ForbiddenDetector
    # 規則の定義に誤りがある場合に投げます。読み込みの失敗はすべてこの型へ寄せます。
    class InvalidRuleError < StandardError; end

    # 調べる値が文字列でない場合に投げます。
    class InvalidInputError < StandardError; end

    RULES_PATH = 'config/forbidden_inputs.yml'

    # 検出の結果です。
    Result = Struct.new(:reasons, keyword_init: true) do
      def forbidden?
        reasons.any?
      end
    end

    # 見つかった理由です。
    Reason = Struct.new(:kind, :matched, :suggestion_key, keyword_init: true) do
      def to_h
        { kind: kind, matched: matched, suggestion_key: suggestion_key }
      end
    end

    def initialize(rules: self.class.load_rules)
      @rules = rules
    end

    class << self
      # 規則を読み込みます。定義が壊れていれば、その場で失敗させます。
      # **空の定義を通しません。** 空で通すと、検査が黙って無効になります。
      def load_rules(path: RULES_PATH)
        rules = read_rules(path)
        raise InvalidRuleError, "規則がありません: #{path}" if rules.empty? # 開発者向け

        rules.map { |rule| build_rule(rule) }
      end

      private

      def read_rules(path)
        loaded = YAML.safe_load_file(Rails.root.join(path))
        raise InvalidRuleError, "規則の定義が読めません: #{path}" unless loaded.is_a?(Hash) # 開発者向け

        rules = loaded['rules']
        raise InvalidRuleError, "規則の定義がありません: #{path}" unless rules.is_a?(Array) # 開発者向け

        rules
      rescue Errno::ENOENT, Psych::SyntaxError => e
        raise InvalidRuleError, "規則の定義を読み込めません: #{path} (#{e.class})" # 開発者向け
      end

      def build_rule(rule)
        patterns = fetch_required(rule, 'patterns')
        raise InvalidRuleError, "検出の語が空です: #{rule.inspect}" if patterns.empty? # 開発者向け

        {
          kind: fetch_required(rule, 'kind').to_sym,
          suggestion_key: fetch_required(rule, 'suggestion_key').to_sym,
          matchers: patterns.map { |pattern| Regexp.new(pattern) }
        }
      end

      def fetch_required(rule, key)
        rule.fetch(key) do
          raise InvalidRuleError, "規則の #{key} がありません: #{rule.inspect}" # 開発者向け
        end
      end
    end

    # 入力を調べます。
    #
    # 空（nil）は「書かれていない」として通します。**それ以外で文字列でない値は
    # 文字列へ直しません。** 直すと、配列や連想配列の書式そのものを検査すること
    # になり、判定の意味が変わります。
    # @return [Result]
    def call(service_summary: nil)
      return Result.new(reasons: []) if service_summary.nil?

      unless service_summary.is_a?(String)
        raise InvalidInputError,
              "文字列を渡してください: #{service_summary.class}" # 開発者向け
      end

      return Result.new(reasons: []) if service_summary.strip.empty?

      detect(service_summary)
    end

    private

    attr_reader :rules

    def detect(text)
      Result.new(reasons: recorded(rules.flat_map { |rule| reasons_for(rule, text) }.uniq))
    end

    # **見つかった箇所をすべて拾います。** 最初の1件だけを見ると、先に書かれた
    # 語で判定が終わり、後ろに書かれた本当の言及を取りこぼします。
    #
    # 重なり合う箇所は、長いほうだけを残します。同じ言及に対して規則が2つ当たると
    # （「大谷翔平さん」と「大谷翔平」）、同じ相手について2行お伝えすることになります。
    def reasons_for(rule, text)
      taken = []

      matches_in(rule, text).filter_map do |matched|
        span = matched.begin(0)...matched.end(0)
        next if taken.any? { |other| overlap?(other, span) }

        taken << span
        Reason.new(kind: rule[:kind], matched: matched[0],
                   suggestion_key: rule[:suggestion_key])
      end
    end

    # 見つかった箇所を、前から順に、長いものを先に並べます。
    #
    # `scan` の戻り値へ `map` をつなぐと、`Regexp.last_match` が最後の1件に
    # 固定されます。列挙しながら取り出す形にします。
    def matches_in(rule, text)
      rule[:matchers]
        .flat_map { |matcher| text.to_enum(:scan, matcher).map { Regexp.last_match } }
        .sort_by { |matched| [matched.begin(0), -matched[0].length] }
    end

    def overlap?(one, other)
      one.cover?(other.first) || other.cover?(one.first)
    end

    # 差し戻した事実を記録へ残します。
    #
    # **残すのは種別と件数だけです。** 見つかった語には実在の方のお名前が
    # 入り得ます。記録は保管期間が長く、閲覧できる範囲も広くなります。
    # 誤って止めていないかを運用で追う目的は、種別と件数でも果たせます。
    def recorded(reasons)
      return reasons if reasons.empty?

      Trace.step('generation.forbidden_detected',
                 kinds: reasons.map(&:kind).uniq,
                 count: reasons.size) { reasons }
    end
  end
end
