# frozen_string_literal: true

module Generation
  # アートディレクションノートの「出来上がった絵で確かめること」です
  # （requirements.md 4.1 の 9）。
  #
  # **仕様が定める 3 点を必ず含みます。**
  #
  #   1. コピースペースの可読性
  #   2. ブランドカラーの再現度
  #   3. クリシェ混入の有無
  #
  # **控えを読みます。「無いこと」から推し量りません。**
  # 当てなかった理由は、各段が控えへ残しています（PR #159 のレビューより）。
  class NoteCheckpoints
    SCOPE = ArtDirectionNote::SCOPE

    def initialize(draft)
      @draft = draft
    end

    # @return [Array<ArtDirectionNote::Checkpoint>]
    def build
      [copy_space, brand_color, cliche, person_safety].compact
    end

    private

    attr_reader :draft

    def checkpoint(key, body)
      ArtDirectionNote::Checkpoint.new(key: key, heading: heading(key), text: body)
    end

    def heading(key)
      I18n.t("#{SCOPE}.headings.#{key}")
    end

    def label(key)
      I18n.t("#{SCOPE}.labels.#{key}")
    end

    def text(key, **)
      I18n.t("#{SCOPE}.#{key}", **)
    end

    def joined(values)
      values.join(label(:separator))
    end

    # **余白の指定が無い案は、使わないようにお伝えします。**
    # 4.2 は「コピースペースを持たない案を出力しない」と定めています。
    # ここへ届くのは組み立ての誤りですが、**利用者が気づける形で残します。**
    def copy_space
      note = find(CopySpace::NOTE_KIND)
      return checkpoint(:copy_space, text('checkpoints.copy_space_missing')) if note.nil?

      checkpoint(:copy_space, text('checkpoints.copy_space', position: position_label(note)))
    end

    def position_label(note)
      I18n.t("input_choices.labels.copy_space_positions.#{note[:position]}")
    end

    # **弱めた色と、そのまま入れた色を分けて確かめていただきます。**
    #
    # 弱めた色について「アクセントとして現れていますか」と尋ねると、
    # 「ほのかに感じる程度まで弱めました」という説明と**逆のこと**を言います。
    def brand_color
      colors = draft.notes.select { |note| note[:kind] == ConflictResolver::BRAND_COLOR_NOTE_KIND }
      return checkpoint(:brand_color, text('checkpoints.brand_color_absent')) if colors.empty?

      accents, weakened = colors.partition do |note|
        note[:strength] != BrandColorIntegration::WEAKENED
      end

      checkpoint(:brand_color, brand_color_text(accents, weakened))
    end

    def brand_color_text(accents, weakened)
      return weakened_color_text(weakened) if accents.empty?
      return accent_color_text(accents) if weakened.empty?

      [accent_color_text(accents), weakened_color_text(weakened)].join(label(:sentence_separator))
    end

    def accent_color_text(accents)
      text('checkpoints.brand_color', colors: joined(accents.pluck(:name)))
    end

    def weakened_color_text(weakened)
      text('checkpoints.brand_color_weakened', colors: joined(weakened.pluck(:name)))
    end

    def cliche
      checkpoint(:cliche, text('checkpoints.cliche'))
    end

    # **控えを読みます。** 抽象背景の案（issue #50）は、そもそも人物を置かない案です。
    def person_safety
      applied = find(StyleSpec::PERSON_SAFETY_NOTE_KIND)
      return checkpoint(:person_safety, applied_text(applied)) if applied
      return checkpoint(:person_safety, text('checkpoints.person_safety_dropped')) if dropped?

      skipped = find(StyleSpec::PERSON_SAFETY_SKIPPED_NOTE_KIND)
      skipped ? checkpoint(:person_safety, skipped_text(skipped)) : nil
    end

    def applied_text(applied)
      text('checkpoints.person_safety', compositions: joined(Array(applied[:compositions])))
    end

    # **理由ごとに、お伝えする内容を分けます。**
    def skipped_text(skipped)
      return text('checkpoints.person_safety_unlikely') if unlikely?(skipped)

      text('checkpoints.person_safety_no_rule')
    end

    def unlikely?(skipped)
      skipped[:reason] == StyleSpec::SKIPPED_BECAUSE_PEOPLE_UNLIKELY
    end

    # 案ごとに外した場合です（issue #50）。
    def dropped?
      draft.notes.any? do |note|
        note[:kind] == VariationExpander::DROPPED_NOTE_KIND &&
          note[:role] == VariationBuilder::PERSON_SAFETY_ROLE
      end
    end

    def find(kind)
      draft.notes.find { |note| note[:kind] == kind }
    end
  end
end
