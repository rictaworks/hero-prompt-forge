# frozen_string_literal: true

module Generation
  # 矛盾の解決と統合です（requirements.md 4.1 の 5、4.2）。
  #
  # 入力どうしが衝突したときは、次の優先順位で統合します。
  #
  #   ① コピースペースの確保 ＞ ② ブランドカラー ＞ ③ スタイル系統 ＞ ④ トーン装飾
  #
  # **出力を止めません。** 矛盾する入力を受けても、統合した案を返します
  # （requirements.md 4.2）。**ただし、統合した内容をノートへ必ず残します。**
  # アートディレクションノート（issue #51）が、それを利用者へ見せます。
  #
  # **ブランドカラーは支配色にしません。アクセントとして統合します。**
  # 支配色にすると、業種の雰囲気も撮影の指示も、その色に塗りつぶされます。
  #
  # **ブランドカラー由来の指示は、落とさずに弱めます。**
  # アンチAIルック規則は、当たった素材を丸ごと落とします。規則辞書に `teal`
  # のような色の語が登録されると、利用者が指定したブランドカラーが黙って
  # 消えます。**4.1 の 5 は、下位の指定を「捨てる」のではなく「弱める」と
  # 定めています**（PR #135 の申し送り）。
  #
  # **色コードではなく色の名前で渡します。** 生成モデルは `#0E7C7B` を色として
  # 受け取りません。名前は ColorName が求めます。
  class ConflictResolver
    # 規則辞書が渡されていない場合に投げます。
    class MissingDictionaryError < StandardError; end

    # 統合の規則が読めない、または内容が足りない場合に投げます。
    class InvalidDefinitionError < StandardError; end

    # 下書きにトーンが入っていない場合に投げます。
    class MissingToneError < StandardError; end

    # ノートに残す印です。文言ではなく記号で持ちます。
    BRAND_COLOR_NOTE_KIND = :brand_color_integrated
    TONE_NOTE_KIND = :tone_integrated

    # ブランドカラーの統合の強さです。
    ACCENT = :accent
    SECONDARY_ACCENT = :secondary_accent
    WEAKENED = :weakened

    def initialize(dictionary:)
      raise MissingDictionaryError, '規則辞書がありません。' if dictionary.nil? # 開発者向け

      @rules = AntiAiRules.new(dictionary)
      @definition = IntegrationRules.load
    end

    # 統合した下書きを返します。
    # @return [Draft]
    def resolve(draft)
      colors = brand_color_integrations(draft)
      tone = tone_integration(draft)

      traced(draft, colors, tone)
    end

    private

    attr_reader :rules, :definition

    def traced(draft, colors, tone)
      Trace.step('generation.conflicts_resolved',
                 brand_colors: colors.size,
                 weakened: colors.count { |item| item[:strength] == WEAKENED },
                 tone: tone[:tone]) do
        integrated(draft, colors, tone)
      end
    end

    def integrated(draft, colors, tone)
      draft.add(
        main_terms: colors.pluck(:term) + tone[:terms],
        notes: colors.map { |item| color_note(item) } + [tone_note(tone)]
      )
    end

    # ブランドカラーを、強さの順に統合します。
    #
    # **1 色目をアクセント、2 色目をそれを支える細部として扱います。**
    # 2 色を同じ強さで指定すると、どちらが主なのか決まりません。
    def brand_color_integrations(draft)
      colors = Array(draft.input.is_a?(Hash) ? draft.input[:brand_colors] : nil)

      colors.each_with_index.map do |color, index|
        strength = index.zero? ? ACCENT : SECONDARY_ACCENT
        build_integration(color, strength)
      end
    end

    # **アンチAIルック規則に当たる場合は、落とさずに弱めます。**
    def build_integration(color, strength)
      name = ColorName.of(color)
      term = format(definition.dig('brand_color', strength.to_s), color: name)
      matched = rules.forbidden_match(term)
      return { color: color, name: name, strength: strength, term: term, matched: nil } if matched.nil?

      { color: color, name: name, strength: WEAKENED, matched: matched,
        term: format(definition.dig('brand_color', WEAKENED.to_s), color: name) }
    end

    def color_note(item)
      { kind: BRAND_COLOR_NOTE_KIND, color: item[:color], name: item[:name],
        strength: item[:strength], matched: item[:matched] }
    end

    # トーン装飾を統合します。**いちばん弱い指定です。**
    #
    # **余白の帯まで飾りません。** 飾ると文字が読めなくなります。
    # コピースペースを確保している下書きにだけ、余白を守る指定を足します。
    def tone_integration(draft)
      tone = tone_of(draft)
      terms = [definition.fetch('tones').fetch(tone) do
        raise InvalidDefinitionError, "トーンの装飾がありません: #{tone}" # 開発者向け
      end]
      terms << definition.fetch('tone_restraint') if CopySpace.reserved?(draft)

      { tone: tone, terms: terms, restrained: CopySpace.reserved?(draft) }
    end

    def tone_note(tone)
      { kind: TONE_NOTE_KIND, tone: tone[:tone], restrained: tone[:restrained] }
    end

    # **トーンは必ず決まっています。** 入力の正規化が、指定が無ければ業種の
    # 標準で補います。ここへ届かないのは組み立ての誤りですので、既定へ寄せず
    # 失敗させます。
    def tone_of(draft)
      value = draft.input.is_a?(Hash) ? draft.input[:brand_tone] : nil
      return value if value.is_a?(String) && !value.strip.empty?

      raise MissingToneError,
            "下書きにトーンがありません: #{value.inspect}" # 開発者向け
    end
  end
end
