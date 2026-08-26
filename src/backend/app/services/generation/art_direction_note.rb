# frozen_string_literal: true

module Generation
  # アートディレクションノートです（requirements.md 4.1 の 9、4.2）。
  #
  # **生成後に人間が確認すべき観点を、案ごとに添えます。**
  # 生成 AI の出力は、指示どおりとは限りません。**出来上がった絵を見て
  # 確かめていただく必要があります。**
  #
  # 添えるのは 2 つです。
  #
  #   checkpoints : 出来上がった絵で確かめること
  #   adjustments : この案で調整したこと
  #
  # **確かめることは、仕様が定める 3 点を必ず含みます。**
  #
  #   1. コピースペースの可読性
  #   2. ブランドカラーの再現度
  #   3. クリシェ混入の有無
  #
  # **調整したことは、控え（ノート）から組み立てます。** 各段は、何をどう
  # 扱ったかを控えへ残しています。**推し量りません。**
  #
  # **文言を実装の中へ書きません。** `config/locales/ja.yml` にあります。
  class ArtDirectionNote
    # 下書きでないものを渡された場合に投げます。
    class InvalidDraftError < StandardError; end

    # 文言の置き場です。
    SCOPE = 'art_direction_note'

    # 添える内容です。
    Note = Struct.new(:checkpoints, :adjustments, keyword_init: true) do
      def to_h
        { checkpoints: checkpoints, adjustments: adjustments }
      end
    end

    # 確かめることの 1 件です。
    Checkpoint = Struct.new(:key, :heading, :text, keyword_init: true) do
      def to_h
        { key: key, heading: heading, text: text }
      end
    end

    # 案ごとのノートを返します。
    # @return [Note]
    def for(draft)
      ensure_draft!(draft)

      Trace.step('generation.art_direction_note_built',
                 checkpoints: 0, notes: draft.notes.size) do
        Note.new(checkpoints: checkpoints_for(draft), adjustments: adjustments_for(draft))
      end
    end

    private

    def ensure_draft!(draft)
      return if draft.respond_to?(:notes) && draft.respond_to?(:main_terms)

      raise InvalidDraftError, "下書きを渡してください: #{draft.class}" # 開発者向け
    end

    # **仕様が定める 3 点を必ず含みます。** 人物の写り方は、当てた場合だけ足します。
    def checkpoints_for(draft)
      [copy_space_checkpoint(draft),
       brand_color_checkpoint(draft),
       cliche_checkpoint,
       person_safety_checkpoint(draft)].compact
    end

    def checkpoint(key, text)
      Checkpoint.new(key: key, heading: heading(key), text: text)
    end

    def heading(key)
      I18n.t("#{SCOPE}.headings.#{key}")
    end

    def text(key, **)
      I18n.t("#{SCOPE}.#{key}", **)
    end

    # **語を並べるときの区切りも、実装の中へ書きません。**
    def joined(values)
      values.join(I18n.t("#{SCOPE}.headings.separator"))
    end

    # **余白の指定が無い案は、使わないようにお伝えします。**
    # 4.2 は「コピースペースを持たない案を出力しない」と定めています。
    # ここへ届くのは組み立ての誤りですが、**利用者が気づける形で残します。**
    def copy_space_checkpoint(draft)
      note = find_note(draft, CopySpace::NOTE_KIND)
      return checkpoint(:copy_space, text('checkpoints.copy_space_missing')) if note.nil?

      checkpoint(:copy_space,
                 text('checkpoints.copy_space', position: position_label(note[:position])))
    end

    def position_label(position)
      I18n.t("input_choices.headings.copy_space_positions.#{position}")
    end

    def brand_color_checkpoint(draft)
      colors = color_notes(draft)
      return checkpoint(:brand_color, text('checkpoints.brand_color_absent')) if colors.empty?

      checkpoint(:brand_color,
                 text('checkpoints.brand_color', colors: joined(colors.pluck(:name))))
    end

    def cliche_checkpoint
      checkpoint(:cliche, text('checkpoints.cliche'))
    end

    def person_safety_checkpoint(draft)
      applied = find_note(draft, StyleSpec::PERSON_SAFETY_NOTE_KIND)
      return checkpoint(:person_safety, text('checkpoints.person_safety_skipped')) if applied.nil?

      checkpoint(:person_safety,
                 text('checkpoints.person_safety',
                      compositions: joined(Array(applied[:compositions]))))
    end

    # **控えから組み立てます。推し量りません。**
    def adjustments_for(draft)
      AdjustmentList.new(draft).build
    end

    def color_notes(draft)
      draft.notes.select { |note| note[:kind] == ConflictResolver::BRAND_COLOR_NOTE_KIND }
    end

    def find_note(draft, kind)
      draft.notes.find { |note| note[:kind] == kind }
    end
  end
end
