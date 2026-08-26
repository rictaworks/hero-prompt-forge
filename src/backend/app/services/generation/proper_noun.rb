# frozen_string_literal: true

module Generation
  # 日本語固有名詞の保持です（requirements.md 4.1 の 6）。
  #
  # **翻訳しません。** 「櫻花堂」を "Cherry Blossom Hall" と訳すと、別の店の
  # 名前になります。**読みをローマ字で写し、何を指す名前かを併記します。**
  #
  # 見つける手がかりは `config/proper_nouns.yml` にあります。**語彙を並べません。**
  # 店名・社名は無数にあり、並べ切れません。名前の形で見分けます。
  #
  # **読みが分からない漢字は、ローマ字へ直しません。** 「東海林」は「しょうじ」
  # とも「とうかいりん」とも読みます。推し量ると別の名前になりますので、
  # 元の表記のまま残し、読みが分からない事実をノートへ残します。
  # アートディレクションノート（issue #51）が、利用者へ読みの追記を促せます。
  #
  # **読みが丸括弧で添えられていれば、それを使います。**
  # 「櫻花堂（おうかどう）」は、日本語の商用文で普通に使われる書き方です。
  class ProperNoun
    # 定義が読めない、または内容が足りない場合に投げます。
    class InvalidDefinitionError < StandardError; end

    # 調べる値が文字列でない場合に投げます。
    class InvalidInputError < StandardError; end

    DEFINITION_PATH = 'config/proper_nouns.yml'

    # ノートに残す印です。文言ではなく記号で持ちます。
    NOTE_KIND = :proper_noun_preserved

    # 会社の名前を表す種別です。**末尾の語を落とすのは、この種別だけです。**
    COMPANY_KIND = :company

    # 読みが添えられている書き方です。「櫻花堂（おうかどう）」の形です。
    READING_IN_PARENTHESES = /[（(]([ぁ-ゖァ-ヴー]{1,20})[）)]/
    # かぎ括弧の閉じです。読みは閉じ括弧の後ろに続きます。
    CLOSING_QUOTE = /[」』]/

    # 読みが分からないまま残した名前に添える説明です。
    KEPT_AS_WRITTEN = 'kept as written in Japanese'

    # 見つかった固有名詞です。
    Found = Struct.new(:original, :romaji, :gloss, :kind, keyword_init: true) do
      # 読みが分かったかどうかを返します。
      def readable?
        !romaji.nil?
      end

      # プロンプトへ入れる 1 件の指示です。
      #
      # **読みが分かった場合はローマ字を、分からない場合は元の表記を使います。**
      # どちらの場合も、意味説明を併記します。翻訳はしません。
      def term
        readable? ? "#{romaji}, #{gloss}" : "#{original}, #{gloss} #{KEPT_AS_WRITTEN}"
      end

      # **ノートの `kind` はノートの種別です。** 名前の種別は `name_kind` で
      # 持ちます。同じ鍵にすると、どちらの意味か読めなくなります。
      def to_h
        { original: original, romaji: romaji, gloss: gloss,
          name_kind: kind, readable: readable? }
      end
    end

    def initialize(rules: self.class.load_rules,
                   suffix_readings: self.class.load_suffix_readings,
                   attribute_words: self.class.load_attribute_words)
      @rules = rules
      @suffix_readings = suffix_readings
      @company_name = CompanyName.new(attribute_words)
      @name_reading = NameReading.new(suffix_readings)
    end

    class << self
      # 手がかりを読み込みます。定義が壊れていれば、その場で失敗させます。
      def load_rules(path: DEFINITION_PATH)
        ProperNounRules.load_rules(path)
      end

      # 屋号の語尾の読みを読み込みます。
      def load_suffix_readings(path: DEFINITION_PATH)
        ProperNounRules.load_suffix_readings(path)
      end

      # 会社名のうしろに付きやすい語を読み込みます。
      def load_attribute_words(path: DEFINITION_PATH)
        ProperNounRules.load_attribute_words(path)
      end
    end

    # 文章から固有名詞を見つけます。
    # @return [Array<Found>]
    def call(service_summary: nil)
      return [] if service_summary.nil?

      unless service_summary.is_a?(String)
        raise InvalidInputError,
              "文字列を渡してください: #{service_summary.class}" # 開発者向け
      end

      recorded(found_in(service_summary))
    end

    # 見つけた固有名詞を下書きへ足します。
    # @return [Draft]
    def apply(draft)
      summary = draft.input.is_a?(Hash) ? draft.input[:service_summary] : nil
      found = call(service_summary: summary)
      return draft if found.empty?

      draft.add(main_terms: found.map(&:term),
                notes: found.map { |item| { kind: NOTE_KIND }.merge(item.to_h) })
    end

    private

    attr_reader :rules, :suffix_readings, :company_name, :name_reading

    def found_in(text)
      rules.flat_map { |rule| matches_for(rule, text) }
           .uniq(&:original)
    end

    # **見つかった位置ごとに扱います。**
    # 位置を見ずに名前だけで読みを引くと、同じ手がかりが 2 度当たったときに、
    # **別の名前へ付いた読みを取り違えます**（PR #149 のレビューより）。
    def matches_for(rule, text)
      rule[:matchers].flat_map { |matcher| matches_of(matcher, text) }
                     .filter_map { |matched| build_found(rule, matched, text) }
    end

    def matches_of(matcher, text)
      text.to_enum(:scan, matcher).map { Regexp.last_match }
    end

    # **同じ名前を 2 度足しません。**
    def build_found(rule, matched, text)
      name = named(rule, matched[1])
      return nil if name.nil? || name.strip.empty?

      Found.new(original: name, romaji: romaji_for(name, matched, text),
                gloss: rule[:gloss], kind: rule[:kind])
    end

    # **末尾の「の◯◯」を落とすのは、会社の名前だけです。**
    # かぎ括弧で明示された名前は、そのまま使います（PR #157 のレビューより）。
    def named(rule, captured)
      rule[:kind] == COMPANY_KIND ? company_name.trimmed(captured) : captured
    end

    # 読みの決め方は NameReading が持ちます。
    def romaji_for(name, matched, text)
      name_reading.romaji_for(name, matched, text)
    end

    # 見つけた事実を記録へ残します。
    #
    # **残すのは種別と件数だけです。** 名前そのものには、実在の店名・社名が
    # 入ります。記録は保管期間が長く、閲覧できる範囲も広くなります。
    def recorded(found)
      return found if found.empty?

      Trace.step('generation.proper_noun_found',
                 kinds: found.map(&:kind).uniq,
                 count: found.size,
                 unreadable: found.count { |item| !item.readable? }) { found }
    end
  end
end
