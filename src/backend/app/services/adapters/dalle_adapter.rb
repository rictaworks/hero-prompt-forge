# frozen_string_literal: true

module Adapters
  # DALL-E 系の記法です（requirements.md 4.1 の 7）。
  #
  # **自然文で書きます。** 組み立ては NarrativeAdapter が持ちます。
  #
  # **打ち消しの欄を持ちません。** 「出さないでほしいもの」を伝える場所が
  # ありませんので、**避けたい表現は本文へ入れません。**
  # `no ...` と書くと、かえってその要素を呼び込むことが知られています。
  #
  # そのかわり、**アンチAIルック規則が素材の側で取り除いています**
  # （issue #40）。打ち消しに頼らず、素材の段階で入れないという設計です。
  #
  # **画像の大きさは画素で指定します。** この呼び出しは `16:9` のような比を
  # 受け付けません（PR #154 のレビューより）。受け付ける大きさは決まった数しか
  # ありませんので、**横長のうち最も近いもの**を選び、**正確な比は本文で伝えます。**
  class DalleAdapter < NarrativeAdapter
    MODEL_KEY = 'dalle'

    # 画像の大きさのパラメータです。
    SIZE_PARAMETER = 'size'

    # 大きさの対応表の鍵です。
    SIZES_KEY = 'sizes'

    class << self
      def model_key = MODEL_KEY
    end

    # **打ち消しの欄を持ちません。**
    def negative_prompt?
      false
    end

    private

    # **打ち消しの欄がありません。** 空ではなく、無いことを返します。
    def negative_prompt_for(_draft)
      nil
    end

    def parameters_for(draft)
      aspect_ratio = input_value(draft, :aspect_ratio)

      { ASPECT_RATIO_PARAMETER => aspect_ratio, SIZE_PARAMETER => size_for(aspect_ratio) }
    end

    # **知らないアスペクト比は、その場で失敗させます。**
    # 既定の大きさへ寄せると、利用者が選んだのと違う形の絵が出ます。
    def size_for(aspect_ratio)
      sizes = rules[SIZES_KEY]
      size = sizes.is_a?(Hash) ? sizes[aspect_ratio] : nil
      return size if size.is_a?(String) && !size.strip.empty?

      raise InvalidDraftError,
            "画像の大きさの対応がありません: #{aspect_ratio}" # 開発者向け
    end
  end
end
