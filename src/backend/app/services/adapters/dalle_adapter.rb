# frozen_string_literal: true

module Adapters
  # DALL-E 系の記法です（requirements.md 4.1 の 7）。
  #
  # **自然文で書きます。** 語を並べるだけでは、関係が伝わりません。
  #
  # **打ち消しの欄を持ちません。** 「出さないでほしいもの」を伝える場所が
  # ありませんので、**避けたい表現は本文へ入れません。**
  # `no ...` と書くと、かえってその要素を呼び込むことが知られています。
  #
  # そのかわり、**アンチAIルック規則が素材の側で取り除いています**
  # （issue #40）。打ち消しに頼らず、素材の段階で入れないという設計です。
  class DalleAdapter < ModelAdapter
    # 文の区切りです。
    SENTENCE_END = '. '
    # 文の終わりです。
    PERIOD = '.'
    # 先頭に置く言い回しです。ヒーローイメージであることを最初に伝えます。
    OPENING = 'A hero image for a website'

    # **打ち消しの欄を持ちません。**
    def negative_prompt?
      false
    end

    private

    # **箇条書きではなく、文として組み立てます。**
    def main_prompt_for(draft)
      aspect_ratio = input_value(draft, :aspect_ratio)
      sentences = ["#{OPENING}, composed for a #{aspect_ratio} frame"]
      sentences += draft.main_terms.map { |term| term.sub(/\A[a-z]/, &:upcase) }

      "#{sentences.join(SENTENCE_END)}#{PERIOD}"
    end

    # **打ち消しの欄がありません。** 空ではなく、無いことを返します。
    def negative_prompt_for(_draft)
      nil
    end

    def parameters_for(draft)
      { 'size' => input_value(draft, :aspect_ratio) }
    end
  end
end
