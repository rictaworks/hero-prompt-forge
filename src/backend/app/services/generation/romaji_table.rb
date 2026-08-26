# frozen_string_literal: true

module Generation
  # ローマ字の対応表の読み込みと検めです。
  #
  # **対応表は人が編集するデータです。中身を信用しません。**
  # 空の値が混ざると、読みが黙って欠けます。読みが欠けると、固有名詞が
  # 別の名前になります。
  class RomajiTable
    InvalidDefinitionError = Romaji::InvalidDefinitionError

    DIGRAPHS_KEY = 'digraphs'
    SINGLES_KEY = 'singles'

    class << self
      # @return [Hash]
      def load(path)
        loaded = read(path)
        digraphs = loaded[DIGRAPHS_KEY]
        singles = loaded[SINGLES_KEY]
        ensure_table!(digraphs, DIGRAPHS_KEY, path)
        ensure_table!(singles, SINGLES_KEY, path)

        { DIGRAPHS_KEY => digraphs.freeze, SINGLES_KEY => singles.freeze }.freeze
      end

      private

      def read(path)
        loaded = YAML.safe_load_file(Rails.root.join(path))
        return loaded if loaded.is_a?(Hash)

        raise InvalidDefinitionError, "ローマ字の対応表が読めません: #{path}" # 開発者向け
      rescue Errno::ENOENT, Psych::SyntaxError => e
        raise InvalidDefinitionError,
              "ローマ字の対応表を読み込めません: #{path} (#{e.class})" # 開発者向け
      end

      # **値は小文字の英字だけです。**
      # YAML は引用符の無い `no` を真偽値として読みます。混ざると読みが欠けます。
      def ensure_table!(table, key, path)
        unless table.is_a?(Hash) && table.any?
          raise InvalidDefinitionError,
                "ローマ字の対応表がありません: #{key} (#{path})" # 開発者向け
        end

        return if table.values.all? { |value| value.is_a?(String) && value.match?(/\A[a-z]+\z/) }

        raise InvalidDefinitionError,
              "ローマ字の対応表に使えない値があります: #{key} (#{path})" # 開発者向け
      end
    end
  end
end
