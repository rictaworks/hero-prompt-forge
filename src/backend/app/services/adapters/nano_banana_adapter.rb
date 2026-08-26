# frozen_string_literal: true

module Adapters
  # nano banana 系の記法です（requirements.md 4.1 の 7）。
  #
  # **自然文で書きます。** 語を並べるより、文で伝えるほうが意図が通ります。
  # **打ち消しは別の欄です。** 本文とは分けて渡します。
  #
  # DALL-E 系と違い打ち消しの欄を持ちますので、**避けたい表現をそちらへ
  # 回せます。**
  class NanoBananaAdapter < ModelAdapter
    # 文の区切りです。
    SENTENCE_END = '. '
    # 文の終わりです。
    PERIOD = '.'
    # 素材の区切りです。打ち消しの欄で使います。
    SEPARATOR = ', '
    # 先頭に置く言い回しです。
    OPENING = 'A website hero image'

    # **打ち消しの欄を持ちます。**
    def negative_prompt?
      true
    end

    private

    def main_prompt_for(draft)
      aspect_ratio = input_value(draft, :aspect_ratio)
      sentences = ["#{OPENING} in a #{aspect_ratio} frame"]
      sentences += draft.main_terms.map { |term| term.sub(/\A[a-z]/, &:upcase) }

      "#{sentences.join(SENTENCE_END)}#{PERIOD}"
    end

    def negative_prompt_for(draft)
      draft.negative_terms.join(SEPARATOR)
    end

    def parameters_for(draft)
      { 'aspect_ratio' => input_value(draft, :aspect_ratio) }
    end
  end
end
