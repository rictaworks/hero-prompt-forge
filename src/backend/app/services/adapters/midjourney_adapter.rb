# frozen_string_literal: true

module Adapters
  # Midjourney 系の記法です（requirements.md 4.1 の 7）。
  #
  # **語をカンマで並べ、パラメータを `--` で付けます。**
  # 打ち消しは `--no` に並べます。**別の欄を持ちません。**
  #
  #   a calm office, 35mm lens, clear copy space --ar 16:9 --no deformed hands
  #
  # **アスペクト比はパラメータで渡します。** 文章で「16:9 で」と書くより、
  # パラメータのほうが確実に効きます。
  class MidjourneyAdapter < ModelAdapter
    # 素材の区切りです。
    SEPARATOR = ', '
    # 打ち消しのパラメータです。
    NEGATIVE_PARAMETER = '--no'
    # アスペクト比のパラメータです。
    ASPECT_RATIO_PARAMETER = '--ar'

    # **打ち消しの欄を持ちます。** ただしパラメータの中に置きます。
    def negative_prompt?
      true
    end

    private

    def main_prompt_for(draft)
      draft.main_terms.join(SEPARATOR)
    end

    def negative_prompt_for(draft)
      draft.negative_terms.join(SEPARATOR)
    end

    # **パラメータは、そのまま文末へ付けられる形で返します。**
    def parameters_for(draft)
      aspect_ratio = input_value(draft, :aspect_ratio)

      { ASPECT_RATIO_PARAMETER => aspect_ratio,
        NEGATIVE_PARAMETER => draft.negative_terms.join(SEPARATOR) }
    end
  end
end
