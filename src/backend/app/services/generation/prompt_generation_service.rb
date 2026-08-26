# frozen_string_literal: true

module Generation
  # プロンプトパッケージの組み立てです（requirements.md 4.1、4.2、11）。
  #
  # 各段は「下書きを受け取って下書きを返す」部品として揃っています。
  # **それらを決まった順で呼ぶのが、この段の仕事です。**
  #
  #   1. 禁止入力の検出（4.1 の 1）
  #   2. 入力の正規化（4.1 の 1）
  #   3. アンチAIルック規則の適用（4.1 の 2）
  #   4. 日本語固有名詞の保持（4.1 の 6）
  #   5. スタイル系統の仕様化（4.1 の 3）
  #   6. コピースペースの規定（4.1 の 4）
  #   7. 矛盾の解決と統合（4.1 の 5）
  #   8. バリエーション3案の展開（4.1 の 8）
  #   9. モデル別の整形（4.1 の 7）
  #  10. アートディレクションノート（4.1 の 9）
  #
  # **順序をこの段が持ちます。** 4.1 の 5 が定める優先順位（①コピースペースの確保
  # ＞ ②ブランドカラー ＞ ③スタイル系統 ＞ ④トーン装飾）は、統合の段が
  # 解きますが、**その段へ届くまでの順序は、ここが守ります。**
  #
  # **出力の直前に、コピースペースの確保を必ず確かめます。**
  # 4.2 は「コピースペースを持たないヒーローイメージ用プロンプトは出力しない」と
  # 定めています。**確かめるのはノートではなく、実際の素材です。**
  # ノートは後段で消えませんが、素材は消えます。
  #
  # **規則辞書の版は、最初から最後まで 1 つです。** 途中で差し替わると、
  # どの版で作ったのかを追えません（requirements.md 7.2）。
  #
  # **人物の見込みの上書き（issue #147）は、まだつないでいません。**
  # 上書きの仕組みが別の PR で進んでいるためです。**マージ後に、
  # `StyleSpec.new(people_override:)` へプロジェクトの設定を渡してください。**
  class PromptGenerationService
    # 規則辞書が渡されていない場合に投げます。
    class MissingDictionaryError < StandardError; end

    # 禁止入力が見つかった場合に投げます。
    class ForbiddenInputError < StandardError
      attr_reader :reasons

      def initialize(reasons)
        @reasons = reasons
        super("禁止入力が見つかりました: #{reasons.map(&:kind).inspect}") # 開発者向け
      end
    end

    # 出力の直前で、コピースペースの確保が失われていた場合に投げます。
    class MissingCopySpaceError < StandardError; end

    # 規則辞書の版が途中で変わった場合に投げます。
    class VersionMismatchError < StandardError; end

    # 1 案ぶんの出力です。
    Package = Struct.new(:variation, :formatted, :note, :draft, keyword_init: true) do
      def to_h
        { variation: variation, formatted: formatted.to_h, note: note.to_h }
      end
    end

    # @param dictionary [RuleDictionary] 規則辞書です
    def initialize(dictionary:)
      raise MissingDictionaryError, '規則辞書がありません。' if dictionary.nil? # 開発者向け

      @dictionary = dictionary
    end

    # 3 案ぶんのプロンプトパッケージを返します。
    # @return [Array<Package>]
    def call(raw)
      traced(raw) do
        input = normalized(raw)
        expanded(prepared(input)).map { |draft| packaged(draft, input) }
      end
    end

    private

    attr_reader :dictionary

    # **どの段で失敗したかが記録から分かるようにします。**
    def traced(raw, &)
      Trace.step('generation.prompt_package_built',
                 dictionary_version: dictionary.version,
                 fields: raw.is_a?(Hash) ? raw.keys.size : 0, &)
    end

    # 禁止入力の検出と、入力の正規化です。
    #
    # **検出を先に行います。** 正規化は選べない値をその場で失敗させますので、
    # 正規化を先に置くと、権利に関わる理由ではなく形式の誤りとして返ります。
    def normalized(raw)
      detected = Trace.step('generation.forbidden_input_checked') do
        ForbiddenDetector.new.call(service_summary: summary_of(raw))
      end
      raise ForbiddenInputError, detected.reasons if detected.forbidden?

      Trace.step('generation.input_normalized') { InputNormalizer.new(dictionary: dictionary).call(raw) }
    end

    def summary_of(raw)
      return nil unless raw.respond_to?(:[])

      raw[:service_summary] || raw['service_summary']
    end

    # 展開の前までを、決まった順で当てます。
    def prepared(input)
      engine = RuleEngine.new(dictionary: dictionary)
      applied = engine.apply(engine.start(input))
      named = ProperNoun.new.apply(applied)
      spec = StyleSpec.new(dictionary: dictionary).apply(named)

      CopySpace.new.apply(spec)
    end

    # 3 案へ展開し、案ごとに統合します。
    #
    # **統合は案ごとに行います。** 案によって外す素材が違いますので、
    # 先に統合すると、外した素材を指す説明が残ります。
    def expanded(draft)
      VariationExpander.new(dictionary: dictionary).expand(draft).map do |variation|
        ConflictResolver.new(dictionary: dictionary).resolve(variation)
      end
    end

    # 1 案を、出力の形へ整えます。
    def packaged(draft, input)
      ensure_reserved!(draft)
      ensure_same_version!(draft)

      Package.new(variation: variation_of(draft),
                  formatted: Adapters::ModelAdapter.for(input[:target_model]).format(draft),
                  note: ArtDirectionNote.new.for(draft),
                  draft: draft)
    end

    def variation_of(draft)
      draft.notes.find { |note| note[:kind] == VariationExpander::NOTE_KIND }
    end

    # **出力の直前に、コピースペースの確保を必ず確かめます。**
    #
    # **確かめるのはノートではなく、実際の素材です。** ノートは後段で消えませんが、
    # 素材は消えます。アンチAIルック規則の排除する語に当たれば、余白の指定が
    # 丸ごと落ちます。**規則辞書は管理画面から人が編集するデータです。**
    def ensure_reserved!(draft)
      return if CopySpace.reserved?(draft)

      raise MissingCopySpaceError,
            'コピースペースの指定が失われた案は出力しません。' # 開発者向け
    end

    # **規則辞書の版は、最初から最後まで 1 つです。**
    def ensure_same_version!(draft)
      return if draft.dictionary_version == dictionary.version

      raise VersionMismatchError,
            "規則辞書の版が変わりました: #{draft.dictionary_version} -> #{dictionary.version}" # 開発者向け
    end
  end
end
