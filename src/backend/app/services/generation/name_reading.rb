# frozen_string_literal: true

module Generation
  # 固有名詞の読みの決め方です（requirements.md 4.1 の 6）。
  #
  # **読みが分からない漢字は、ローマ字へ直しません。** 「東海林」は「しょうじ」
  # とも「とうかいりん」とも読みます。**読み方を推し量ると、別の名前になります。**
  #
  # 読みが決まるのは 3 通りです。
  #
  #   1. 名前そのものがかなであれば、そのまま写します
  #   2. 名前の直後に丸括弧で読みが添えられていれば、それを使います
  #   3. 屋号の語尾とかなだけでできていれば、語尾の読みで決まります
  class NameReading
    # 閉じかぎ括弧です。読みの直前に挟まります。
    CLOSING_QUOTE = ProperNoun::CLOSING_QUOTE
    # 丸括弧の中の読みです。
    READING_IN_PARENTHESES = ProperNoun::READING_IN_PARENTHESES

    def initialize(suffix_readings)
      @suffix_readings = suffix_readings
    end

    # @return [String, nil] 読みが決まらなければ空です
    def romaji_for(name, matched, text)
      return Romaji.of(name) if Romaji.kana?(name)

      reading = reading_after(matched, text) || suffix_reading(name)
      reading ? Romaji.of(reading) : nil
    end

    private

    attr_reader :suffix_readings

    # **屋号の語尾は読みが決まっています。**
    # かなと語尾だけでできた名前であれば、読みが決まります。
    # 「櫻花堂」のように語尾以外へ漢字が入る場合は、読みが決まりません。
    #
    # **長い語尾から先に引きます。** 「工房」を「房」として読みません。
    def suffix_reading(name)
      suffix_readings.keys.sort_by { |key| -key.length }.each do |suffix|
        next unless name.end_with?(suffix)

        body = name.delete_suffix(suffix)
        return body + suffix_readings[suffix] if !body.empty? && Romaji.kana?(body)
      end

      nil
    end

    # **その名前が見つかった位置の、すぐ後ろだけを見ます。**
    #
    # かぎ括弧でくくられている場合は、閉じ括弧を挟んで読みが続きます
    # （「櫻花堂」（おうかどう））。閉じ括弧 1 文字だけを飛ばします。
    def reading_after(matched, text)
      following = text[matched.end(1)..]
      return nil if following.nil?

      found = following.match(/\A#{CLOSING_QUOTE.source}?#{READING_IN_PARENTHESES.source}/)
      found && found[1]
    end
  end
end
