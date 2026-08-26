# frozen_string_literal: true

module Generation
  # スタイル系統ごとの仕様化です（requirements.md 4.1 の 3、4.2）。
  #
  # 実写系はレンズ焦点距離・照明設計（キーライト／フィルライト／リムライト）・
  # 被写界深度を明示します。イラスト・3D 系は線の質感・マテリアル・レンダリング
  # 様式を明示します。
  #
  # **撮影指示を欠く案を出しません。** 規則辞書に必須の項目が欠けていれば、
  # その場で失敗させます（requirements.md 4.2）。
  #
  # **人物の顔を正面から大きく描く構図は、既定で避けます。** 顔や手指は破綻し
  # やすいため、後ろ姿・手元のクロップ・遠景といった構図で回避します。利用者が
  # 明示した場合のみ許します（requirements.md 4.2）。
  #
  # **当てるのは、人物が写る見込みの業種だけです**（issue #139）。
  # 4.1 の 3 は「人物を含む場合は」と条件付きで定めています。料理・製品・
  # 物件の外観へ「後ろ姿の被写体」を当てると、人物のいないヒーローに人物を
  # 呼び込みます。見込みの判定は PeopleExpectation が持ちます。
  #
  # **当てる構図は 1 つだけです。** 後ろ姿・手元だけ・遠景を同時に指示すると、
  # 生成モデルはどれを採るか決められません（4.1 の 5 が矛盾の解決を求めます）。
  # 一覧の先頭を既定として使います。レンズ焦点距離と同じ扱いです。
  # 案ごとに別の構図を選び直すのは、バリエーションの展開（issue #50）です。
  #
  # 素材は **1 件 1 指示** で足します。1 件へ複数の指示を詰め込むと、
  # アンチAIルック規則（issue #40）が 1 つの語に当たったときに、
  # 関係のない指示まで道連れになります。
  #
  # 素材は英語で作ります。規則辞書の語が英語であり、生成モデルへ渡すのも
  # 英語のためです。**日本語の素材を作りません。** 日本語固有名詞の扱いは
  # issue #44 が受け持ちます。
  #
  # **打ち消しの言い回し（`no ...`）を作りません。** 避けたい表現は、
  # メインプロンプトではなくネガティブプロンプトの側で表します。
  class StyleSpec
    # 規則辞書が渡されていない場合に投げます。
    class MissingDictionaryError < StandardError; end

    # 規則辞書の内容が足りない、または壊れている場合に投げます。
    InvalidDictionaryError = StyleRules::InvalidDictionaryError

    # 定義されていないスタイル系統を渡された場合に投げます。
    UnknownStyleError = StyleRules::UnknownStyleError

    # 下書きにスタイル系統が入っていない場合に投げます。
    class MissingStyleFamilyError < StandardError; end

    # 別の版の規則を、同じ下書きへ重ねて当てようとした場合に投げます。
    class VersionMismatchError < StandardError; end

    # 統合済みの下書きへ仕様化を当てようとした場合に投げます。
    class AlreadyIntegratedError < StandardError; end

    # 規則辞書の業種の既定値が壊れている場合に投げます。
    InvalidPeopleError = PeopleExpectation::InvalidDictionaryError

    # 下書きに業種が入っていない場合に投げます。
    class MissingIndustryError < StandardError; end

    # ノートに残す印です。文言ではなく記号で持ちます。
    #
    # **当てた仕様そのものを残します。** バリエーションの展開（issue #50）が、
    # 案ごとに別の値へ選び直すために使います。素材の並びだけでは、どれが
    # この段の足したものか分かりません。
    SPECIFICATIONS_NOTE_KIND = :style_spec_applied
    PERSON_SAFETY_NOTE_KIND = :person_safety_applied
    # 構図を当てなかったことを残す印です。**理由を添えます。**
    PERSON_SAFETY_SKIPPED_NOTE_KIND = :person_safety_skipped

    # 当てなかった理由です。
    #
    #   people_unlikely : その業種では人物が写らない見込みです
    #   style_has_none  : そのスタイル系統に、避ける構図の定義がありません
    #
    # **理由を分けます。** 一緒にすると、業種が「写る見込み」なのに
    # 業種を理由にしたかのようなノートが残ります（PR #145 のレビューより）。
    # アートディレクションノート（issue #51）は、これをそのまま利用者へ見せます。
    SKIPPED_BECAUSE_PEOPLE_UNLIKELY = :people_unlikely
    SKIPPED_BECAUSE_STYLE_HAS_NONE = :style_has_none

    def initialize(dictionary:)
      raise MissingDictionaryError, '規則辞書がありません。' if dictionary.nil? # 開発者向け

      @rules = StyleRules.new(dictionary)
      @people = PeopleExpectation.new(dictionary: dictionary)
    end

    # スタイル系統の指示を足した下書きを返します。
    # @return [Draft]
    def apply(draft)
      ensure_same_version!(draft)
      ensure_not_integrated!(draft)
      style_family = style_family_of(draft)

      traced(draft, style_family,
             rules.specifications_for(style_family),
             safety_decision(draft, style_family))
    end

    private

    attr_reader :rules, :people

    delegate :version, to: :rules

    # **1つの下書きへ当てる規則辞書は1つだけです。**
    # 生成リクエストが持てる版は1つですので、別の版を重ねると、
    # 前の版で適用した事実が記録から消えます。RuleEngine と同じ扱いにします。
    # **矛盾解決のあとに当てません。** 統合はこの段より後に走ります。
    # あとから仕様化を当てると、**弱めるはずの配色指定がそのまま残ります**
    # （PR #151 の 2 回目のレビューで実測されました）。
    def ensure_not_integrated!(draft)
      return unless ConflictResolver.integrated?(draft)

      raise AlreadyIntegratedError,
            'すでに矛盾解決を適用した下書きへは、仕様化を当てられません。' # 開発者向け
    end

    def ensure_same_version!(draft)
      applied_version = draft.dictionary_version
      return if applied_version.nil? || applied_version == version

      raise VersionMismatchError,
            "別の版の規則は重ねられません: #{applied_version} -> #{version}" # 開発者向け
    end

    # 避ける構図を当てるかどうかを決め、理由とともに返します。
    #
    # **スタイル系統の定義を先に見ます。** 定義が無い系統（イラスト・3D・抽象）で
    # 業種の見込みを引くと、規則辞書に見込みが無いときに、実写系に限らず
    # すべての生成が止まります。影響の範囲を、定義のある系統だけに抑えます
    # （PR #145 のレビューより）。
    #
    # **人物のいないヒーローに人物を呼び込みません。**
    def safety_decision(draft, style_family)
      compositions = rules.person_safety_for(style_family)
      return { compositions: [], reason: SKIPPED_BECAUSE_STYLE_HAS_NONE } if compositions.empty?

      decided = people.decide(industry_of(draft), people_override(draft))
      unless decided[:expected]
        return { compositions: [], reason: SKIPPED_BECAUSE_PEOPLE_UNLIKELY,
                 industry: industry_of(draft), people_source: decided[:source] }
      end

      { compositions: compositions.first(1), reason: nil, people_source: decided[:source] }
    end

    # プロジェクト単位の上書きです（issue #147）。
    #
    # **規則辞書は全利用者で共有される単一のマスタです。** 1 社のために編集すると、
    # 全社の出力が変わります。**業種の中の個別事情は、プロジェクトの側で持ちます。**
    # 上書きが無ければ、これまでどおり業種の既定値を使います。
    def people_override(draft)
      draft.input.is_a?(Hash) ? draft.input[:people] : nil
    end

    # **業種は必須の入力です。** 欠けたまま進むと、人物の見込みを引けません。
    def industry_of(draft)
      industry = draft.input.is_a?(Hash) ? draft.input[:industry] : nil
      return industry if industry.is_a?(String) && !industry.strip.empty?

      raise MissingIndustryError,
            "下書きに業種がありません: #{industry.inspect}" # 開発者向け
    end

    # 何を、どの版で、いくつ足したかを記録へ残します。
    def traced(draft, style_family, specifications, decision)
      Trace.step('generation.style_spec_applied',
                 dictionary_version: version,
                 style_family: style_family,
                 specifications: specifications.size,
                 person_safety: decision[:compositions].size,
                 person_safety_skipped: decision[:reason],
                 people_source: decision[:people_source]) do
        applied(draft, specifications, decision)
      end
    end

    # **適用した版を下書きへ残します。** どの版の仕様化規則で作ったかを、
    # あとから追えるようにするためです（requirements.md 7.2）。
    def applied(draft, specifications, decision)
      draft.add(
        main_terms: specifications + decision[:compositions],
        notes: [specifications_note(draft, specifications), safety_note(decision)],
        dictionary_version: version
      )
    end

    # **当てた仕様そのものを残します。** issue #50 が選び直すために使います。
    def specifications_note(draft, specifications)
      { kind: SPECIFICATIONS_NOTE_KIND, style_family: style_family_of(draft),
        specifications: specifications }
    end

    # **当てた場合も、当てなかった場合も、ノートへ残します。**
    # 当てなかった事実が残らないと、「なぜ人物の構図が入っていないのか」を
    # あとから説明できません。**理由も添えます。**
    def safety_note(decision)
      return applied_note(decision) if decision[:compositions].any?

      note = { kind: PERSON_SAFETY_SKIPPED_NOTE_KIND, reason: decision[:reason] }
      note = note.merge(industry: decision[:industry]) if decision[:industry]
      with_source(note, decision)
    end

    def applied_note(decision)
      with_source({ kind: PERSON_SAFETY_NOTE_KIND, compositions: decision[:compositions] },
                  decision)
    end

    # **どこから引いた見込みかを残します**（issue #147）。
    # プロジェクトで上書きしたのか、業種の既定値なのかが分かります。
    def with_source(note, decision)
      return note if decision[:people_source].nil?

      note.merge(people_source: decision[:people_source])
    end

    # **スタイル系統は必須の入力です。** 欠けたまま進むと、どの仕様を当てるか
    # 決められません。既定へ寄せず、その場で失敗させます。
    def style_family_of(draft)
      style_family = draft.input.is_a?(Hash) ? draft.input[:style_family] : nil
      return style_family if style_family.is_a?(String) && !style_family.strip.empty?

      raise MissingStyleFamilyError,
            "下書きにスタイル系統がありません: #{style_family.inspect}" # 開発者向け
    end
  end
end
