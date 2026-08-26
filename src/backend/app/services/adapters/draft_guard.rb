# frozen_string_literal: true

module Adapters
  # 整形できる下書きかどうかの検めです（requirements.md 4.1 の 7、4.2）。
  #
  # **素材が 1 件も無い下書きを整形しません。**
  # 空の指示を生成モデルへ渡すと、何が出るか決まりません。
  #
  # **コピースペースを持たない下書きも整形しません。**
  # requirements.md 4.2 は「コピースペースを持たないヒーローイメージ用
  # プロンプトは出力しない」と定めています。**整形は出力の直前ですので、
  # ここが最後の関所です。**
  class DraftGuard
    # @raise [ModelAdapter::InvalidDraftError] 整形できない下書きの場合です
    def ensure_formattable!(draft)
      ensure_draft!(draft)
      ensure_terms!(draft)
      ensure_copy_space!(draft)
    end

    private

    def ensure_draft!(draft)
      return if draft.respond_to?(:main_terms) && draft.respond_to?(:negative_terms)

      raise ModelAdapter::InvalidDraftError,
            "下書きを渡してください: #{draft.class}" # 開発者向け
    end

    def ensure_terms!(draft)
      return if draft.main_terms.any?

      raise ModelAdapter::InvalidDraftError, '素材がありません。' # 開発者向け
    end

    def ensure_copy_space!(draft)
      return if Generation::CopySpace.reserved?(draft)

      raise ModelAdapter::InvalidDraftError, 'コピースペースの指定がありません。' # 開発者向け
    end
  end
end
