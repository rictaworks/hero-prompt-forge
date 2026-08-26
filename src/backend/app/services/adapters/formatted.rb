# frozen_string_literal: true

module Adapters
  # 整形の結果です（requirements.md 4.1 の 7、11）。
  #
  # **モデルが受け取れる形に整った、最終の出力です。**
  #
  #   main_prompt     : 本文です。保存と画面表示に使います
  #   negative_prompt : 打ち消しです。**欄を持つモデルだけが値を持ちます**
  #   parameters      : 呼び出しの設定です。**鍵の名前はモデル共通です**
  #   prompt          : **そのまま貼り付けられる最終形です**
  #   notes           : 整形の過程で残した控えです。**すり替えた事実を残します**
  #
  # **本文と最終形を分けて持ちます。** Midjourney 系はパラメータを本文の末尾へ
  # 付けなければ効きません。連結を呼び出す側へ残すと、順序を誤って効かない指示に
  # なります（PR #154 のレビューより）。
  Formatted = Struct.new(:main_prompt, :negative_prompt, :parameters, :prompt, :notes,
                         keyword_init: true) do
    # 打ち消しの欄を持ち、かつ中身があるかどうかを返します。
    def negative?
      !negative_prompt.nil?
    end

    # そのまま貼り付けられる最終形を返します。
    def to_prompt
      prompt
    end

    def to_h
      { main_prompt: main_prompt, negative_prompt: negative_prompt,
        parameters: parameters, prompt: prompt, notes: notes }
    end
  end
end
