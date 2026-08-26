# frozen_string_literal: true

module Generation
  # 統合の規則の読み込みと検めです（requirements.md 4.1 の 5）。
  #
  # **規則は人が編集するデータです。中身を信用しません。**
  # トーンの装飾が 1 つ欠けるだけで、その業種の生成が止まります。
  class IntegrationRules
    InvalidDefinitionError = ConflictResolver::InvalidDefinitionError

    DEFINITION_PATH = 'config/integration_rules.yml'
    BRAND_COLOR_KEY = 'brand_color'
    BRAND_COLOR_RESTRAINT_KEY = 'brand_color_restraint'
    STYLE_PALETTE_CONFLICT_KEY = 'style_palette_conflict'
    TONES_KEY = 'tones'
    TONE_RESTRAINT_KEY = 'tone_restraint'

    # **そのままプロンプトへ入れられる英文の形です。**
    # 印字できる ASCII だけを認めます。日本語が混ざると、そのまま生成モデルへ
    # 渡ります（PR #151 のレビューで実測されました）。
    ENGLISH_TEXT_FORMAT = /\A[\x20-\x7E]+\z/

    # **打ち消しの言い回しです。** 「◯◯を出さないでください」と書くと、
    # かえってその要素を呼び込みます。よく知られた性質です。
    NEGATION_FORMAT = /\b(?:no|not|never|without|avoid|avoiding|free of|lacking)\b/i

    # ブランドカラーの統合の強さです。**3 つとも必ずあります。**
    BRAND_COLOR_STRENGTHS = %w[accent secondary_accent weakened].freeze

    # 色の名前を差し込む場所です。
    COLOR_PLACEHOLDER = '%<color>s'

    # 読み込み時に差し込みを試すための、当たり障りのない色名です。
    PLACEHOLDER_PROBE = 'gray'

    class << self
      # @return [Hash]
      def load(path: DEFINITION_PATH)
        @definition ||= {}
        @definition[path] ||= build(path)
      end

      # テストから読み直せるようにします。**本番の経路では使いません。**
      def reset!
        @definition = nil
      end

      private

      # **読み込みは 1 度だけです。** 生成のたびに YAML を読むと、
      # 1 件の生成で何度も同じファイルを開きます。ColorName と同じ扱いにします
      # （PR #151 のレビューより）。
      def build(path)
        loaded = read(path)
        ensure_all!(loaded, path)

        DeepFreeze.call(loaded)
      end

      def read(path)
        loaded = YAML.safe_load_file(Rails.root.join(path))
        return loaded if loaded.is_a?(Hash)

        raise InvalidDefinitionError, "統合の規則が読めません: #{path}" # 開発者向け
      rescue Errno::ENOENT, Psych::SyntaxError => e
        raise InvalidDefinitionError,
              "統合の規則を読み込めません: #{path} (#{e.class})" # 開発者向け
      end

      def ensure_all!(loaded, path)
        ensure_brand_color!(loaded[BRAND_COLOR_KEY], path)
        ensure_text!(loaded[BRAND_COLOR_RESTRAINT_KEY], BRAND_COLOR_RESTRAINT_KEY, path)
        ensure_style_palette_conflict!(loaded[STYLE_PALETTE_CONFLICT_KEY], path)
        ensure_tones!(loaded[TONES_KEY], path)
        ensure_text!(loaded[TONE_RESTRAINT_KEY], TONE_RESTRAINT_KEY, path)
      end

      # **3 つの強さがすべてそろっていることを求めます。**
      # 弱めた形が欠けると、アンチAIルック規則に当たったブランドカラーを
      # 落とすほかなくなります。4.1 の 5 は「弱める」と定めています。
      def ensure_brand_color!(rule, path)
        unless rule.is_a?(Hash)
          raise InvalidDefinitionError,
                "ブランドカラーの統合の規則がありません: #{path}" # 開発者向け
        end

        BRAND_COLOR_STRENGTHS.each do |strength|
          ensure_text!(rule[strength], "#{BRAND_COLOR_KEY}.#{strength}", path)
          ensure_placeholder!(rule[strength], "#{BRAND_COLOR_KEY}.#{strength}", path)
        end
      end

      # **仕様が定めるトーンをすべて持つことを求めます。**
      # 1 つ欠けると、その業種の生成が止まります。
      def ensure_tones!(tones, path)
        unless tones.is_a?(Hash)
          raise InvalidDefinitionError, "トーンの装飾がありません: #{path}" # 開発者向け
        end

        missing = InputChoices::BRAND_TONES - tones.keys
        unless missing.empty?
          raise InvalidDefinitionError,
                "トーンの装飾が足りません: #{missing.join(', ')} (#{path})" # 開発者向け
        end

        tones.each { |tone, text| ensure_text!(text, "#{TONES_KEY}.#{tone}", path) }
      end

      # **スタイル系統との衝突の規則を検めます。**
      def ensure_style_palette_conflict!(conflict, path)
        unless conflict.is_a?(Hash)
          raise InvalidDefinitionError,
                "スタイル系統との衝突の規則がありません: #{path}" # 開発者向け
        end

        ensure_palette_items!(conflict[StylePalette::ITEMS_KEY], path)
        ensure_text!(conflict[StylePalette::WEAKENED_KEY],
                     "#{STYLE_PALETTE_CONFLICT_KEY}.weakened", path)
      end

      # **配色指定の項目名は、規則辞書の項目名と同じものを書きます。**
      def ensure_palette_items!(items, path)
        return if items.is_a?(Array) && items.any? && items.all?(String)

        raise InvalidDefinitionError,
              "配色指定の項目名がありません: #{STYLE_PALETTE_CONFLICT_KEY} (#{path})" # 開発者向け
      end

      # **そのままプロンプトへ入れられる英文であることを求めます。**
      #
      # 空白だけを弾いても足りません。**日本語も打ち消しも通ります。**
      # 前者はそのまま生成モデルへ渡り、後者はかえってその要素を呼び込みます
      # （PR #151 のレビューで実測されました）。
      def ensure_text!(value, where, path)
        unless value.is_a?(String) && value.strip.present? &&
               value.match?(ENGLISH_TEXT_FORMAT)
          raise InvalidDefinitionError,
                "統合の規則が英文ではありません: #{where} (#{path})" # 開発者向け
        end

        ensure_no_negation!(value, where, path)
      end

      def ensure_no_negation!(value, where, path)
        return unless value.match?(NEGATION_FORMAT)

        raise InvalidDefinitionError,
              "統合の規則に打ち消しの言い回しがあります: #{where} (#{path})" # 開発者向け
      end

      # **色を差し込む場所があることを求めます。**
      # 無いと、どの色を指しているのか分からない指示になります。
      #
      # **実際に差し込んでみます。** 有無だけを見ると、`100% coverage` のような
      # 書き方が読み込み時を素通りし、**生成のたびに落ちます**
      # （PR #151 の 2 回目のレビューで実測されました）。読み込み時に落とします。
      def ensure_placeholder!(value, where, path)
        unless value.include?(COLOR_PLACEHOLDER)
          raise InvalidDefinitionError,
                "色を差し込む場所がありません: #{where} (#{path})" # 開発者向け
        end

        Kernel.format(value, color: PLACEHOLDER_PROBE)
      rescue ArgumentError, KeyError => e
        raise InvalidDefinitionError,
              "色を差し込めない書き方です: #{where} (#{path}) (#{e.class})" # 開発者向け
      end
    end
  end
end
