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
    #
    # **節の見出しも一緒に返します。** 画面（issue #73、#74）が文言を
    # 組み立て直さずに済みます。
    Note = Struct.new(:checkpoints, :adjustments, :headings, keyword_init: true) do
      def to_h
        { checkpoints: checkpoints, adjustments: adjustments, headings: headings }
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

      built = Note.new(checkpoints: checkpoints_for(draft), adjustments: adjustments_for(draft),
                       headings: section_headings)

      Trace.step('generation.art_direction_note_built',
                 checkpoints: built.checkpoints.size,
                 adjustments: built.adjustments.size) { built }
    end

    private

    def ensure_draft!(draft)
      return if draft.respond_to?(:notes) && draft.respond_to?(:main_terms)

      raise InvalidDraftError, "下書きを渡してください: #{draft.class}" # 開発者向け
    end

    # **確かめることは NoteCheckpoints が組み立てます。**
    def checkpoints_for(draft)
      NoteCheckpoints.new(draft).build
    end

    def heading(key)
      I18n.t("#{SCOPE}.headings.#{key}")
    end

    # 節の見出しです。
    def section_headings
      { checkpoints: heading(:checkpoints), adjustments: heading(:adjustments) }
    end

    # **控えから組み立てます。推し量りません。**
    def adjustments_for(draft)
      AdjustmentList.new(draft).build
    end
  end
end
