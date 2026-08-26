# frozen_string_literal: true

module Generation
  # プロンプトを組み立てる途中の下書きです。
  #
  # 規則の適用・スタイルの仕様化・コピースペースの規定・矛盾の解決を、
  # この入れ物を受け渡しながら順に進めます（requirements.md 4.1 の 2 から 5）。
  #
  # **書き換えられません。** 各段は新しい下書きを返します。途中で誰が何を足したのかを
  # 追えるようにするためです。書き換える作りにすると、順序を変えたときの影響が
  # 読めなくなります。
  #
  # 凍らせるのは器だけではありません。**中身まで凍らせます。** 器だけを凍らせても、
  # 連想配列の中の値は書き換えられ、「書き換えません」という約束が守られません。
  #
  # **複製してから凍らせます。** 渡された配列をその場で凍らせると、下書きを作った
  # だけで、呼び出す側の配列が使えなくなります。
  class Draft
    # 正規化済みの入力です。
    attr_reader :input
    # メインプロンプトの素材です。
    attr_reader :main_terms
    # ネガティブプロンプトの素材です。
    attr_reader :negative_terms
    # アートディレクションノートの素材です。
    attr_reader :notes
    # 適用した規則辞書の版です。
    attr_reader :dictionary_version

    def initialize(input:, main_terms: [], negative_terms: [], notes: [], dictionary_version: nil)
      @input = self.class.deep_copy_freeze(input)
      @main_terms = self.class.deep_copy_freeze(main_terms)
      @negative_terms = self.class.deep_copy_freeze(negative_terms)
      @notes = self.class.deep_copy_freeze(notes)
      @dictionary_version = dictionary_version.freeze
      freeze
    end

    # 複製して、中身まで凍らせます。
    #
    # 器だけでは、連想配列の中の値を書き換えられます。複製しないと、渡した側の
    # 配列まで凍ります。
    def self.deep_copy_freeze(value)
      case value
      when Hash then value.to_h { |key, item| [key, deep_copy_freeze(item)] }.freeze
      when Array then value.map { |item| deep_copy_freeze(item) }.freeze
      when String then value.dup.freeze
      else value.freeze
      end
    end

    # 素材を足した下書きを返します。同じ語は重ねません。
    def add(main_terms: [], negative_terms: [], notes: [], dictionary_version: nil)
      replace(
        main_terms: (@main_terms + main_terms).uniq,
        negative_terms: (@negative_terms + negative_terms).uniq,
        notes: @notes + notes,
        dictionary_version: dictionary_version || @dictionary_version
      )
    end

    # 指定した部分だけを差し替えた下書きを返します。
    def replace(main_terms: nil, negative_terms: nil, notes: nil, dictionary_version: nil)
      self.class.new(
        input: @input,
        main_terms: main_terms || @main_terms,
        negative_terms: negative_terms || @negative_terms,
        notes: notes || @notes,
        dictionary_version: dictionary_version || @dictionary_version
      )
    end

    def ==(other)
      other.is_a?(self.class) && to_h == other.to_h
    end

    def to_h
      {
        input: @input,
        main_terms: @main_terms,
        negative_terms: @negative_terms,
        notes: @notes,
        dictionary_version: @dictionary_version
      }
    end
  end
end
