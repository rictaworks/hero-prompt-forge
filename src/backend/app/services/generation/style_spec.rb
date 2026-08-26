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

    # ノートに残す印です。文言ではなく記号で持ちます。
    PERSON_SAFETY_NOTE_KIND = :person_safety_applied

    def initialize(dictionary:)
      raise MissingDictionaryError, '規則辞書がありません。' if dictionary.nil? # 開発者向け

      @rules = StyleRules.new(dictionary)
    end

    # スタイル系統の指示を足した下書きを返します。
    # @return [Draft]
    def apply(draft)
      style_family = style_family_of(draft)
      specifications = rules.specifications_for(style_family)
      safety = rules.person_safety_for(style_family)

      Trace.step('generation.style_spec_applied',
                 style_family: style_family,
                 specifications: specifications.size,
                 person_safety: safety.size) do
        applied(draft, specifications, safety)
      end
    end

    private

    attr_reader :rules

    def applied(draft, specifications, safety)
      draft.add(
        main_terms: specifications + safety,
        notes: safety.empty? ? [] : [{ kind: PERSON_SAFETY_NOTE_KIND, compositions: safety }]
      )
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
