# frozen_string_literal: true

module Generation
  # プロンプトパッケージの組み立てです（requirements.md 4.1、4.2、11）。
  #
  # 各段は「下書きを受け取って下書きを返す」部品として揃っています。
  # **それらを決まった順で呼ぶのが、この段の仕事です。**
  #
  #   1. 入力の正規化（4.1 の 1）
  #   2. 禁止入力の検出（4.1 の 1）
  #   3. 日本語固有名詞の保持（4.1 の 6）
  #   4. スタイル系統の仕様化（4.1 の 3）
  #   5. コピースペースの規定（4.1 の 4）
  #   6. アンチAIルック規則の適用（4.1 の 2）
  #   7. バリエーション3案の展開（4.1 の 8）
  #   8. 矛盾の解決と統合（4.1 の 5）
  #   9. モデル別の整形（4.1 の 7）
  #  10. アートディレクションノート（4.1 の 9）
  #
  # **正規化を、禁止入力の検出より先に置きます。** 検出は文章を舐めますので、
  # **長さの上限を通していない文字列を渡すと、際限なく時間がかかります**
  # （PR #163 のレビューで、400 万字に 2.28 秒かかることが実測されました）。
  # 形・型・長さは、正規化が項目名を添えて検めます。
  #
  # **アンチAIルック規則は、素材がそろってから当てます。** 4.1 の並びのまま
  # 最初に当てると、**当てる相手が 1 件もありません**（issue #161）。
  # 排除する語は 1 件も働かず、規則辞書へクリシェの語を足しても効きません。
  # **統合より前であれば、弱めて残したブランドカラーを消す心配もありません。**
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

    # 展開の前に当てる段です。**この並びが工程の順です。**
    #
    # **一覧で持ちます。** 呼び出しを直に並べると、1 つ外してもどのテストも
    # 落ちません（PR #163 のレビューで実測されました）。
    STEPS = %i[proper_nouns style_spec copy_space anti_ai_rules].freeze

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

    # 入力の正規化と、禁止入力の検出です。
    #
    # **正規化を先に行います。** 検出は文章を舐めますので、長さの上限を
    # 通していない文字列を渡すと、際限なく時間がかかります
    # （PR #163 のレビューで、400 万字に 2.28 秒かかることが実測されました）。
    # **形・型・長さは、正規化が項目名を添えて検めます。**
    def normalized(raw)
      input = Trace.step('generation.input_normalized') do
        InputNormalizer.new(dictionary: dictionary).call(raw)
      end
      ensure_allowed!(input)

      input
    end

    # **権利に触れる入力は、枠を使う前に止めます**（requirements.md 4.1 の 1）。
    def ensure_allowed!(input)
      detected = Trace.step('generation.forbidden_input_checked') do
        ForbiddenDetector.new.call(service_summary: input[:service_summary])
      end
      return unless detected.forbidden?

      raise ForbiddenInputError, detected.reasons
    end

    # 展開の前までを、決まった順で当てます。
    #
    # **段の並びを一覧で持ちます。** 呼び出しを直に並べると、1 つ外しても
    # どのテストも落ちません（PR #163 のレビューで実測されました）。
    def prepared(input)
      engine = RuleEngine.new(dictionary: dictionary)

      STEPS.reduce(engine.start(input)) { |draft, step| apply_step(step, draft, engine) }
    end

    def apply_step(step, draft, engine)
      case step
      when :proper_nouns then ProperNoun.new.apply(draft)
      when :style_spec then StyleSpec.new(dictionary: dictionary).apply(draft)
      when :copy_space then CopySpace.new.apply(draft)
      when :anti_ai_rules then engine.apply(draft)
      end
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
