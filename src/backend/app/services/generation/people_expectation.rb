# frozen_string_literal: true

module Generation
  # そのヒーローイメージに人物が写るかどうかの見込みです（issue #139）。
  #
  # requirements.md 4.1 の 3 は「**人物を含む場合は**顔・手指の破綻リスクを
  # 構図（後ろ姿・手元クロップ・遠景）で回避する」と、条件付きで定めています。
  # 条件を見ずに当てると、料理・製品・工場・不動産の外観といった人物のいない
  # ヒーローへ、人物を呼び込みます。
  #
  # **判定は業種の既定値（規則辞書）から引きます。** 3 つの案から選びました。
  #
  #   A 入力項目を足す        : 仕様の入力表（4.1）に無い項目を増やします
  #   B サービス概要から推定  : **推測で補わない方針と衝突します**
  #   C 業種の既定値に持たせる : 管理画面から運用で調整できます  <- これを採ります
  #
  # **B を採りません。** 入力の正規化は「推測で補いません。選べない値を
  # 受け取ったら、その場で失敗させます」という方針で作られています。文面から
  # 人物の有無を推し量ると、外したときに利用者の意図と違う指示が黙って入ります。
  #
  # **A を採りません。** 仕様の入力表を増やすことになります。仕様の正は
  # requirements.md であり、実装の都合で項目を足しません。
  #
  # **C の弱点は、業種の中の個別事情を拾えないことです。** 「製造」でも製品だけを
  # 写したい場合があります。**規則辞書は全利用者で共有される単一のマスタですので、
  # 1 社のために編集すると全社の出力が変わります**（PR #145 のレビューより）。
  #
  # そこで、**プロジェクト単位の上書き**を受け取れるようにしました（issue #147）。
  # 上書きは `projects.brand_settings` に持ちます。**入力表を増やしません。**
  # 仕様の正は requirements.md であり、実装の都合で入力項目を足しません。
  #
  # **上書きが無ければ、これまでどおり業種の既定値を使います。**
  # **どちらを使ったかは、必ず記録へ残します。** アートディレクションノート
  # （issue #51）が、それを利用者へ見せます。
  class PeopleExpectation
    # 規則辞書に見込みの定義が無い、または値が選択肢の外の場合に投げます。
    class InvalidDictionaryError < StandardError; end

    # 業種の既定値のうち、人物の見込みを表す鍵です。
    PEOPLE_KEY = 'people'

    # 選べる値です。
    EXPECTED = 'expected'
    UNLIKELY = 'unlikely'
    CHOICES = [EXPECTED, UNLIKELY].freeze

    # どこから引いた見込みかを表す印です。
    #
    #   industry : 業種の既定値（規則辞書）です
    #   project  : プロジェクト単位の上書きです
    FROM_INDUSTRY = :industry
    FROM_PROJECT = :project

    # 上書きの値が選択肢の外の場合に投げます。
    class InvalidOverrideError < StandardError; end

    def initialize(dictionary:)
      @dictionary = dictionary
    end

    # 人物が写る見込みかどうかを返します。
    #
    # @param industry [String] 業種です
    # @param override [String, nil] プロジェクト単位の上書きです
    # @return [Boolean]
    def expected?(industry, override: nil)
      decide(industry, override)[:expected]
    end

    # 見込みと、その出どころを返します。
    #
    # **どちらを使ったかを記録へ残すために使います。**
    # @return [Hash] `:expected` と `:source` を持ちます
    def decide(industry, override = nil)
      return from_override(override) unless override.nil?

      value = dictionary.defaults_for(industry)[PEOPLE_KEY]
      ensure_choice!(industry, value)

      { expected: value == EXPECTED, source: FROM_INDUSTRY, value: value }
    end

    private

    attr_reader :dictionary

    # **上書きの値が選択肢の外なら、その場で失敗させます。**
    # 既定へ寄せると、書き間違えた上書きが黙って無視されます。
    def from_override(override)
      unless CHOICES.include?(override)
        raise InvalidOverrideError,
              "人物の見込みの上書きが選べない値です: #{override.inspect}" # 開発者向け
      end

      { expected: override == EXPECTED, source: FROM_PROJECT, value: override }
    end

    # **定義が無い場合も、選択肢の外の値も、その場で失敗させます。**
    # 既定へ寄せると、規則辞書の編集で定義が消えたときに、人物の回避が
    # 黙って効かなくなります（または、人物のいない絵へ人物が入ります）。
    def ensure_choice!(industry, value)
      return if CHOICES.include?(value)

      raise InvalidDictionaryError,
            "業種の人物の見込みが選べない値です: #{industry} -> #{value.inspect}" # 開発者向け
    end
  end
end
