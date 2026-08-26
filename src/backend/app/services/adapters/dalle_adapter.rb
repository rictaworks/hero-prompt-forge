# frozen_string_literal: true

module Adapters
  # DALL-E 系の記法です（requirements.md 4.1 の 7）。
  #
  # **自然文で書きます。** 組み立ては NarrativeAdapter が持ちます。
  #
  # **打ち消しの欄を持ちません。** 「出さないでほしいもの」を伝える場所が
  # ありませんので、**避けたい表現は本文へ入れません。**
  # `no ...` と書くと、かえってその要素を呼び込むことが知られています。
  #
  # そのかわり、**アンチAIルック規則が素材の側で取り除いています**
  # （issue #40）。打ち消しに頼らず、素材の段階で入れないという設計です。
  #
  # **画像の大きさは画素で指定します。** この呼び出しは `16:9` のような比を
  # 受け付けません（PR #154 のレビューより）。受け付ける大きさは決まった数しか
  # ありませんので、**横長のうち最も近いもの**を選び、**正確な比は本文で伝えます。**
  #
  # **すり替えた事実を控えへ残します。** 黙って寄せると、`aspect_ratio` ・
  # `size` ・ 本文の 3 つが別の比を指し、受け取った利用者はどれに従えばよいか
  # 決められません。アートディレクションノート（issue #51）が、これを見せます。
  class DalleAdapter < NarrativeAdapter
    MODEL_KEY = 'dalle'

    # 画像の大きさのパラメータです。
    SIZE_PARAMETER = 'size'

    # 大きさの対応表の鍵です。
    SIZES_KEY = 'sizes'

    # 対象の呼び出しの版の鍵です。
    API_VERSION_KEY = 'api_version'

    # 記法が必ず持つ鍵です。**版の記載も求めます。**
    REQUIRED_KEYS = (NarrativeAdapter::REQUIRED_KEYS + [API_VERSION_KEY]).freeze

    # 画像の大きさの形です。**画素で書きます。**
    SIZE_FORMAT = /\A\d+x\d+\z/

    # 大きさをすり替えたことを残す印です。
    SIZE_SUBSTITUTED_NOTE_KIND = :size_substituted

    class << self
      def model_key = MODEL_KEY

      def required_keys = REQUIRED_KEYS
    end

    # **打ち消しの欄を持ちません。**
    def negative_prompt?
      false
    end

    private

    # **選べる大きさが、指定された比と違う場合は控えへ残します。**
    #
    # 黙って寄せると、`aspect_ratio` ・ `size` ・ 本文の 3 つが別の比を指し、
    # 受け取った利用者はどれに従えばよいか決められません
    # （PR #154 の 2 回目のレビューより）。
    def notes_for(draft)
      aspect_ratio = input_value(draft, :aspect_ratio)
      size = size_for(aspect_ratio)
      return [] if same_ratio?(aspect_ratio, size)

      [{ kind: SIZE_SUBSTITUTED_NOTE_KIND, aspect_ratio: aspect_ratio, size: size,
         api_version: rules.fetch(API_VERSION_KEY) }]
    end

    # 指定された比と、選んだ大きさの比が同じかどうかを返します。
    def same_ratio?(aspect_ratio, size)
      ratio_of(aspect_ratio, ':') == ratio_of(size, 'x')
    end

    def ratio_of(value, separator)
      width, height = value.split(separator).map(&:to_f)
      return nil if height.nil? || height.zero?

      (width / height).round(2)
    end

    # **打ち消しの欄がありません。** 空ではなく、無いことを返します。
    def negative_prompt_for(_draft)
      nil
    end

    def parameters_for(draft)
      aspect_ratio = input_value(draft, :aspect_ratio)

      { ASPECT_RATIO_PARAMETER => aspect_ratio, SIZE_PARAMETER => size_for(aspect_ratio) }
    end

    # **知らないアスペクト比は、その場で失敗させます。**
    # 既定の大きさへ寄せると、利用者が選んだのと違う形の絵が出ます。
    def size_for(aspect_ratio)
      size = sizes[aspect_ratio]
      return size if size

      raise InvalidDefinitionError,
            "画像の大きさの対応がありません: #{aspect_ratio}" # 開発者向け
    end

    # 大きさの対応表です。**中身を信用しません。**
    # 比のまま書かれていると、この呼び出しに弾かれます。
    def sizes
      table = rules[SIZES_KEY]
      return table if valid_sizes?(table)

      raise InvalidDefinitionError,
            "画像の大きさの対応表が読めません: #{self.class.model_key}.#{SIZES_KEY}" # 開発者向け
    end

    def valid_sizes?(table)
      table.is_a?(Hash) && table.any? &&
        table.all? { |ratio, size| ratio.is_a?(String) && size.is_a?(String) && size.match?(SIZE_FORMAT) }
    end
  end
end
