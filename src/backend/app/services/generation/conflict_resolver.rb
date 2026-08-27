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

    # 下書きにスタイル系統が入っていない場合に投げます。
    MissingStyleFamilyError = StyleSpec::MissingStyleFamilyError

    # コピースペースを確保していない下書きを渡された場合に投げます。
    class MissingCopySpaceError < StandardError; end

    # すでに統合済みの下書きへ、もう一度当てようとした場合に投げます。
    class AlreadyIntegratedError < StandardError; end

    # ノートに残す印です。文言ではなく記号で持ちます。
    BRAND_COLOR_NOTE_KIND = :brand_color_integrated
    TONE_NOTE_KIND = :tone_integrated
    # 色を余白へ入り込ませない指定の控えです（issue #156）。
    BRAND_COLOR_RESTRAINT_NOTE_KIND = :brand_color_restraint_applied

    # 役割の名前です。**整形の段（issue #156）が、述語を選ぶために引きます。**
    BRAND_COLOR_ROLE = 'brand_color'
    BRAND_COLOR_RESTRAINT_ROLE = 'brand_color_restraint'
    TONE_ROLE = 'tone'
    TONE_RESTRAINT_ROLE = 'tone_restraint'
    STYLE_PALETTE_NOTE_KIND = StylePalette::NOTE_KIND

    # ブランドカラーの統合の強さです。**扱いは BrandColorIntegration が持ちます。**
    ACCENT = BrandColorIntegration::ACCENT
    SECONDARY_ACCENT = BrandColorIntegration::SECONDARY_ACCENT
    WEAKENED = BrandColorIntegration::WEAKENED

    def initialize(dictionary:)
      raise MissingDictionaryError, '規則辞書がありません。' if dictionary.nil? # 開発者向け

      @rules = AntiAiRules.new(dictionary)
      @style_rules = StyleRules.new(dictionary)
      @definition = IntegrationRules.load
    end

    # 統合した下書きを返します。
    # @return [Draft]
    def resolve(draft)
      ensure_not_integrated!(draft)
      ensure_reserved!(draft)
      colors = brand_color_integrations(draft)
      styles = style_palette_weakenings(draft, colors)
      tone = tone_integration(draft)

      traced(draft, colors, styles, tone)
    end

    # その下書きが統合済みかどうかを返します。
    #
    # **統合のあとにアンチAIルック規則を当てないための関所です。**
    # 弱めて残したブランドカラーは、当たった語（`teal` など）をそのまま含みます。
    # そのあとに規則を当てると、**弱めた素材ごと落ちます。** ノートは
    # 「弱めて残しました」と残るため、**説明と実物が食い違います。**
    # 黙って消えるより悪い状態です（PR #151 のレビューで実測されました）。
    #
    # **トーンの統合は必ず行われます。** ブランドカラーの指定が無くても
    # 残りますので、統合済みかどうかの印として使えます。
    def self.integrated?(draft)
      draft.notes.any? { |note| note[:kind] == TONE_NOTE_KIND }
    end

    private

    attr_reader :rules, :style_rules, :definition

    # **コピースペースを確保していない下書きは統合しません。**
    #
    # requirements.md 4.2 は「コピースペースを持たない案を出しません」と定め、
    # 4.1 は矛盾解決を余白の確保より後に置いています。**正しい順序なら、
    # 確保されていない下書きはここへ届きません。** 届いたのは組み立ての誤りです。
    #
    # **黙って余白を守る指定を省きません。** 省くと、余白の帯が飾られた案が
    # そのまま出ます。本プロジェクトはフォールバックを禁じています
    # （PR #151 の 2 回目のレビューより）。
    def ensure_reserved!(draft)
      return if CopySpace.reserved?(draft)

      raise MissingCopySpaceError,
            'コピースペースを確保していない下書きは統合できません。' # 開発者向け
    end

    # **2 回当てません。** ノートだけが二重に残り、
    # アートディレクションノートが同じ説明を繰り返します。
    def ensure_not_integrated!(draft)
      return unless self.class.integrated?(draft)

      raise AlreadyIntegratedError,
            '矛盾解決はすでに適用されています。' # 開発者向け
    end

    def traced(draft, colors, styles, tone)
      Trace.step('generation.conflicts_resolved',
                 brand_colors: colors.size,
                 weakened: colors.count { |item| item[:strength] == WEAKENED },
                 style_palettes_weakened: styles[:notes].size,
                 tone: tone[:tone]) do
        integrated(draft, colors, styles, tone)
      end
    end

    def integrated(draft, colors, styles, tone)
      draft.replace(main_terms: styles[:main_terms]).add(
        main_terms: colors.pluck(:term) + color_restraint(colors) + tone[:terms],
        notes: colors.map { |item| color_note(item) } + color_restraint_note(colors) +
               styles[:notes] + [tone_note(tone)]
      )
    end

    # **アクセントを余白へ入り込ませません。**
    #
    # 優先順位の ① は余白の確保、② がブランドカラーです。アクセントを置く
    # オブジェクトが余白側へ来ると、二番目の指定が最上位の指定を侵します。
    #
    # **余白の確保は入口で求めています。** ここでは色の指定の有無だけを見ます。
    def color_restraint(colors)
      return [] if colors.empty?

      [definition.fetch('brand_color_restraint')]
    end

    # **色を余白へ入り込ませない指定の役割です**（issue #156）。
    # 配色ではなく構図の指定ですので、役割を分けます。
    def color_restraint_note(colors)
      return [] if colors.empty?

      [{ kind: BRAND_COLOR_RESTRAINT_NOTE_KIND,
         roles: { BRAND_COLOR_RESTRAINT_ROLE => definition.fetch('brand_color_restraint') } }]
    end

    # **スタイル系統の配色指定を弱めます。** 弱め方は StylePalette が持ちます。
    #
    # **ブランドカラーの指定が無ければ、衝突しません。** そのままにします。
    def style_palette_weakenings(draft, colors)
      return { main_terms: draft.main_terms, notes: [] } if colors.empty?

      StylePalette.for(definition: definition, style_rules: style_rules,
                       style_family: style_family_of(draft))
                  .weaken(draft.main_terms)
    end

    # **スタイル系統は必須の入力です。** 欠けたまま進むと、どの配色指定と
    # ぶつかっているのか決められません。
    def style_family_of(draft)
      value = draft.input.is_a?(Hash) ? draft.input[:style_family] : nil
      return value if value.is_a?(String) && !value.strip.empty?

      raise MissingStyleFamilyError,
            "下書きにスタイル系統がありません: #{value.class}" # 開発者向け
    end

    # ブランドカラーを、強さの順に統合します。**扱いは BrandColorIntegration です。**
    def brand_color_integrations(draft)
      colors = Array(draft.input.is_a?(Hash) ? draft.input[:brand_colors] : nil)

      BrandColorIntegration.new(rules: rules, definition: definition).integrations_for(colors)
    end

    # **役割の名前も一緒に残します**（issue #156）。整形の段は、色の指定を
    # 「画に写っているもの」ではなく「配色」として述べます。
    def color_note(item)
      { kind: BRAND_COLOR_NOTE_KIND, color: item[:color], name: item[:name],
        strength: item[:strength], matched: item[:matched], term: item[:term],
        roles: { BRAND_COLOR_ROLE => item[:term] } }
    end

    # トーン装飾を統合します。**いちばん弱い指定です。**
    #
    # **余白の帯まで飾りません。** 飾ると文字が読めなくなります。
    # **余白の確保は入口で求めていますので、必ず足します。**
    def tone_integration(draft)
      tone = tone_of(draft)
      terms = [definition.fetch('tones').fetch(tone) do
        raise InvalidDefinitionError, "トーンの装飾がありません: #{tone}" # 開発者向け
      end]
      terms << definition.fetch('tone_restraint')

      { tone: tone, terms: terms, restrained: true }
    end

    # **役割の名前も一緒に残します**（issue #156）。
    #
    # トーンの素材は 2 つです。1 つ目が全体の雰囲気、2 つ目が余白を飾らない
    # ための指定です。**後者は構図の指定ですので、役割を分けます。**
    def tone_note(tone)
      { kind: TONE_NOTE_KIND, tone: tone[:tone], restrained: tone[:restrained],
        terms: tone[:terms], roles: tone_roles(tone[:terms]) }
    end

    def tone_roles(terms)
      roles = { TONE_ROLE => terms.first }
      roles[TONE_RESTRAINT_ROLE] = terms.second if terms.size > 1
      roles
    end

    # **トーンは必ず決まっています。** 入力の正規化が、指定が無ければ業種の
    # 標準で補います。ここへ届かないのは組み立ての誤りですので、既定へ寄せず
    # 失敗させます。
    def tone_of(draft)
      value = draft.input.is_a?(Hash) ? draft.input[:brand_tone] : nil
      return value if value.is_a?(String) && !value.strip.empty?

      raise MissingToneError,
            "下書きにトーンがありません: #{value.class}" # 開発者向け
    end
  end
end
