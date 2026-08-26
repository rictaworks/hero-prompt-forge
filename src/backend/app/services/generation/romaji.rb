# frozen_string_literal: true

module Generation
  # かなをローマ字へ直します（requirements.md 4.1 の 6）。
  #
  # **翻訳しません。読みをそのまま写します。** 「櫻花堂」を
  # "Cherry Blossom Hall" と訳すと、別の店の名前になります。
  #
  # 方式はヘボン式です。対応表は `config/kana_romanization.yml` にあります。
  #
  # **かなだけを扱います。** 漢字の読みは、文字だけからは決まりません
  # （「東海林」は「しょうじ」とも「とうかいりん」とも読みます）。
  # 漢字を含む固有名詞の扱いは ProperNoun が持ちます。
  class Romaji
    # 対応表の定義に誤りがある場合に投げます。
    class InvalidDefinitionError < StandardError; end

    # かなでない文字が混ざっている場合に投げます。
    class NotKanaError < StandardError; end

    DEFINITION_PATH = 'config/kana_romanization.yml'
    DIGRAPHS_KEY = 'digraphs'
    SINGLES_KEY = 'singles'

    # ひらがなの範囲です。
    HIRAGANA = /\A[ぁ-ゖー・\s]+\z/
    # 促音です。次の子音を重ねます（「がっこう」→ "gakkou"）。
    SOKUON = 'っ' # 開発者向け（文字そのものであり、画面へ出す文言ではありません）
    # 長音記号です。直前の母音を伸ばさず、そのまま落とします。
    # 英語話者にとって "Ra-men" より "Ramen" のほうが読みやすいためです。
    CHOUON = 'ー' # 開発者向け（同上）
    # 中黒です。語の区切りとして空白に直します。
    NAKAGURO = '・' # 開発者向け（同上）

    class << self
      # かなの並びをローマ字へ直します。
      # @return [String]
      def of(kana)
        normalized = to_hiragana(kana.to_s)
        ensure_kana!(kana, normalized)

        capitalize(convert(normalized))
      end

      # かなだけでできているかどうかを返します。
      def kana?(text)
        to_hiragana(text.to_s).match?(HIRAGANA)
      end

      # テストから読み直せるようにします。**本番の経路では使いません。**
      def reset!
        @definition = nil
      end

      private

      # カタカナをひらがなへ寄せます。対応表を 1 つに保つためです。
      def to_hiragana(text)
        text.tr('ァ-ヴ', 'ぁ-ゔ') # 開発者向け（文字の範囲であり、画面へ出す文言ではありません）
      end

      def ensure_kana!(original, normalized)
        return if normalized.match?(HIRAGANA)

        raise NotKanaError,
              "かなではない文字が含まれています: #{original.inspect}" # 開発者向け
      end

      # 語ごとに先頭を大文字にします。固有名詞として読みやすくするためです。
      def capitalize(romaji)
        romaji.split.map { |word| word.empty? ? word : word[0].upcase + word[1..] }
              .join(' ')
      end

      def convert(kana)
        letters = []
        index = 0
        while index < kana.length
          consumed, romaji = read_at(kana, index)
          letters << romaji
          index += consumed
        end
        letters.join.squeeze(' ').strip
      end

      # その位置から読める、いちばん長い単位を読みます。
      #
      # **拗音を先に見ます。** 1 文字ずつ読むと「きゃ」が "kiya" になります。
      def read_at(kana, index)
        pair = kana[index, 2]
        return [2, digraphs[pair]] if pair && digraphs.key?(pair)

        [1, single_at(kana, index)]
      end

      def single_at(kana, index)
        letter = kana[index]
        return doubled_consonant(kana, index) if letter == SOKUON
        return '' if letter == CHOUON
        return ' ' if letter == NAKAGURO || letter.match?(/\s/)

        singles.fetch(letter) do
          raise InvalidDefinitionError,
                "対応表に無いかなです: #{letter.inspect}" # 開発者向け
        end
      end

      # 促音は、次の音の子音を重ねます。次が無ければ落とします。
      def doubled_consonant(kana, index)
        _consumed, following = read_at(kana, index + 1)
        return '' if following.blank?

        following[0]
      end

      def digraphs
        definition[DIGRAPHS_KEY]
      end

      def singles
        definition[SINGLES_KEY]
      end

      def definition
        @definition ||= RomajiTable.load(DEFINITION_PATH)
      end
    end
  end
end
