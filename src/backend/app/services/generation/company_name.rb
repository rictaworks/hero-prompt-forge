# frozen_string_literal: true

module Generation
  # 会社名の切り出しの整えです（issue #153）。
  #
  # **拾った名前の末尾が「の＋会社そのものを指さない語」で終わる場合、そこを
  # 落とします。** 「株式会社みらいの強みは提案力です。」から `みらいの強み` を
  # 拾うと、名前でない語がそのまま生成モデルへ渡ります。
  #
  # **「の」が名前の一部か、文をつなぐ助詞かは、文字だけでは決まりません。**
  # 「株式会社さくらの家」の「の」は名前の一部です。
  #
  # **既定は「そのまま残す」です。** 落とすのは、会社の紹介文でよく使われる語で
  # 終わる場合だけです。**名前の本体から「の」を外す形は採りません。**
  # その形では、「みのり」「ものづくり研究所」のように **「の」が語中にある名前**が
  # 最初の「の」で切れます（PR #157 のレビューで実測されました）。
  class CompanyName
    # @param definition [Hash] 助詞と、語の一覧です
    def initialize(definition)
      @particle = definition.fetch(ProperNounRules::ATTRIBUTE_PARTICLE_KEY)
      @attribute_words = definition.fetch(ProperNounRules::ATTRIBUTE_WORDS_KEY)
      @non_name_words = definition.fetch(ProperNounRules::NON_NAME_WORDS_KEY)
      @particles = definition.fetch(ProperNounRules::PARTICLES_KEY)
    end

    # 末尾の「の◯◯」を落とした名前を返します。
    #
    # **重ねて落とします。** 「みらいの事業の強み」は「みらい」になります。
    #
    # **すべて落ちた場合は、名前がなかったものとして扱います。**
    # 「株式会社の設立をご支援します。」の `の設立` は、会社名ではありません
    # （PR #157 の 2 回目のレビューより）。
    # @return [String, nil]
    def trimmed(name)
      return name if name.nil?

      trimmed = name
      while (word = trailing_attribute(trimmed))
        trimmed = trimmed[0..-(particle.length + word.length + 1)]
      end

      named?(trimmed) ? trimmed : nil
    end

    private

    attr_reader :particle, :attribute_words, :non_name_words, :particles

    # 会社名として扱える形かどうかを返します。
    #
    # **助詞かどうかを、手がかりの側で決めません**（PR #157 の 3 回目のレビューより）。
    # 「へいわ」「よりみち」「からだ工房」「やまと」「このは」のように、
    # **助詞と同じ字で始まる名前・終わる名前がふつうにあります。**
    # 拾ったあとで、会社名でない形だけを落とします。
    def named?(name)
      return false if name.empty?
      return false if particles.include?(name)

      non_name_words.none? { |word| name.start_with?(word) || name.include?(word) }
    end

    # 末尾に付いている、会社そのものを指さない語です。**無ければ空です。**
    def trailing_attribute(name)
      attribute_words.find { |word| name.end_with?("#{particle}#{word}") }
    end
  end
end
