# frozen_string_literal: true

module Adapters
  # モデルアダプタの共通の約束です（requirements.md 4.1 の 7、11）。
  #
  # 生成モデルごとに記法が違います。**同じ素材から、モデルが受け取れる形へ
  # 整えるのが、この層の仕事です。**
  #
  #   Midjourney 系      : 語を並べ、パラメータを本文の末尾へ付けます
  #   DALL-E 系          : 自然文で書きます。**打ち消しの欄がありません**
  #   Stable Diffusion 系 : 語を並べ、重み付けを括弧で表します。打ち消しは別の欄です
  #   nano banana 系      : 自然文で書きます。**打ち消しの欄がありません**
  #
  # **記法の違いを、素材を作る側へ持ち込みません。** 素材は 1 件 1 指示の
  # 英文のままにしておき、ここで初めてモデルの都合に合わせます。
  #
  # **貼り付けられる最終形まで、この層で決めきります。** パラメータを本文の
  # どこへ置くかはモデルごとに違います。連結を呼び出す側へ残すと、順序を誤って
  # 効かない指示になります（PR #154 のレビューより）。
  #
  # **未対応のモデルを渡されたら、その場で失敗させます。**
  # 既定のモデルへ寄せると、利用者が選んだのと違う記法の指示が出ます。
  class ModelAdapter
    # 未対応のモデルを渡された場合に投げます。
    class UnknownModelError < StandardError; end

    # 整形に必要な内容が下書きに無い場合に投げます。
    class InvalidDraftError < StandardError; end

    # 素材が、そのモデルの記法を壊す文字を含む場合に投げます。
    class UnsafeTermError < StandardError; end

    # 実装していない約束を呼ばれた場合に投げます。
    #
    # **Ruby が持つ `NotImplementedError` と同じ名前にしません。**
    # この名前空間の中で、組み込みの例外を覆い隠します。
    class AdapterNotImplementedError < StandardError; end

    # パラメータの鍵です。**どのモデルでも同じ名前で持ちます。**
    # モデルごとに鍵が違うと、受け取った側が一様に扱えません。
    ASPECT_RATIO_PARAMETER = 'aspect_ratio'

    # 整形の結果は Formatted が持ちます。
    class << self
      # 生成モデルに対応するアダプタを返します。
      #
      # **知らないモデルは、その場で失敗させます。**
      # @return [ModelAdapter]
      def for(target_model)
        adapter = registry[target_model]
        return adapter.new if adapter

        raise UnknownModelError,
              "対応していない生成モデルです: #{target_model.class} / " \
              "対応しているのは #{supported_models.join(', ')} です" # 開発者向け
      end

      # 対応している生成モデルです。
      def supported_models
        registry.keys
      end

      # 生成モデルの識別子です。**各アダプタが必ず名乗ります。**
      def model_key
        raise AdapterNotImplementedError, "#{self} が model_key を実装していません" # 開発者向け
      end

      # そのアダプタの記法が必ず持つ鍵です。
      def required_keys
        raise AdapterNotImplementedError, "#{self} が required_keys を実装していません" # 開発者向け
      end

      # **仕様が定める 4 系統をすべて持ちます**（requirements.md 4.1）。
      def adapters
        [MidjourneyAdapter, DalleAdapter, StableDiffusionAdapter, NanoBananaAdapter]
      end

      private

      def registry
        adapters.index_by(&:model_key)
      end
    end

    # 下書きを、そのモデルの記法へ整えます。
    # @return [Formatted]
    def format(draft)
      ensure_draft!(draft)

      Trace.step('adapters.formatted',
                 target_model: self.class.model_key,
                 terms: draft.main_terms.size,
                 negative_terms: draft.negative_terms.size,
                 negative_field: negative_prompt?) do
        formatted(draft)
      end
    end

    # このアダプタが打ち消しの欄を持つかどうかを返します。
    def negative_prompt?
      raise AdapterNotImplementedError,
            "#{self.class} が negative_prompt? を実装していません" # 開発者向け
    end

    private

    def formatted(draft)
      main_prompt = main_prompt_for(draft)

      Formatted.new(
        main_prompt: main_prompt,
        negative_prompt: negative_prompt_for(draft),
        parameters: parameters_for(draft),
        prompt: prompt_for(draft, main_prompt)
      )
    end

    # **既定では、本文がそのまま最終形です。**
    # パラメータを本文へ付けるモデルだけが、これを上書きします。
    def prompt_for(_draft, main_prompt)
      main_prompt
    end

    # このアダプタの記法です。
    def rules
      @rules ||= AdapterRules.for(self.class.model_key, keys: self.class.required_keys)
    end

    # **素材が 1 件も無い下書きを整形しません。**
    # 空の指示を生成モデルへ渡すと、何が出るか決まりません。
    #
    # **コピースペースを持たない下書きも整形しません。**
    # requirements.md 4.2 は「コピースペースを持たないヒーローイメージ用
    # プロンプトは出力しない」と定めています。**ここが最後の関所です。**
    def ensure_draft!(draft)
      unless draft.respond_to?(:main_terms) && draft.respond_to?(:negative_terms)
        raise InvalidDraftError, "下書きを渡してください: #{draft.class}" # 開発者向け
      end

      raise InvalidDraftError, '素材がありません。' if draft.main_terms.empty? # 開発者向け
      return if Generation::CopySpace.reserved?(draft)

      raise InvalidDraftError, 'コピースペースの指定がありません。' # 開発者向け
    end

    def main_prompt_for(_draft)
      raise AdapterNotImplementedError,
            "#{self.class} が main_prompt_for を実装していません" # 開発者向け
    end

    def negative_prompt_for(_draft)
      raise AdapterNotImplementedError,
            "#{self.class} が negative_prompt_for を実装していません" # 開発者向け
    end

    def parameters_for(_draft)
      raise AdapterNotImplementedError,
            "#{self.class} が parameters_for を実装していません" # 開発者向け
    end

    # 下書きの入力から値を取り出します。**欠けていれば失敗させます。**
    #
    # **例外に、利用者由来の値そのものを入れません。** 正規化を通らずにここへ
    # 届いた場合、記録へそのまま流れます（PR #154 のレビューより）。
    def input_value(draft, key)
      value = draft.input.is_a?(Hash) ? draft.input[key] : nil
      return value if value.is_a?(String) && !value.strip.empty?

      raise InvalidDraftError, "下書きに #{key} がありません: #{value.class}" # 開発者向け
    end

    # 打ち消しの素材を 1 本にまとめます。**1 件も無ければ、無いことを返します。**
    def joined_negative_terms(draft)
      return nil if draft.negative_terms.empty?

      draft.negative_terms.join(rules.fetch('term_separator'))
    end
  end
end
