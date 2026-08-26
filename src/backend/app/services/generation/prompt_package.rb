# frozen_string_literal: true

module Generation
  # 1 案ぶんのプロンプトパッケージです（requirements.md 4.2、11）。
  #
  #   variation : 何案目か・どの構図か
  #   formatted : 選ばれた生成モデルの記法へ整えた出力
  #   note      : アートディレクションノート
  #   draft     : 組み立ての途中の下書き。**控えを引くために持ちます**
  PromptPackage = Struct.new(:variation, :formatted, :note, :draft, keyword_init: true) do
    def to_h
      { variation: variation, formatted: formatted.to_h, note: note.to_h,
        degraded: degraded? }
    end

    # **縮退して作られた案かどうかを返します**（issue #53）。
    def degraded?
      DegradedComposer.degraded?(draft)
    end

    # 何案目かです。
    def number
      variation[:number]
    end

    # 構図の種別です。
    def composition_type
      variation[:composition]
    end
  end
end
