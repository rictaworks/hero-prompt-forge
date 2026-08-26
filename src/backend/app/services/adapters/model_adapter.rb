# frozen_string_literal: true

module Adapters
  # モデルアダプタの共通の約束です（requirements.md 4.1 の 7、11）。
  #
  # 生成モデルごとに記法が違います。**同じ素材から、モデルが受け取れる形へ
  # 整えるのが、この層の仕事です。**
  #
  #   Midjourney 系      : パラメータを `--` で付けます。打ち消しは `--no` です
  #   DALL-E 系          : 自然文で書きます。**打ち消しの欄がありません**
  #   Stable Diffusion 系 : 語を並べ、重み付けを括弧で表します。打ち消しは別の欄です
  #   nano banana 系      : 自然文で書きます。打ち消しは別の欄です
  #
  # **記法の違いを、素材を作る側へ持ち込みません。** 素材は 1 件 1 指示の
  # 英文のままにしておき、ここで初めてモデルの都合に合わせます。
  #
  # **未対応のモデルを渡されたら、その場で失敗させます。**
  # 既定のモデルへ寄せると、利用者が選んだのと違う記法の指示が出ます。
  class ModelAdapter
    # 未対応のモデルを渡された場合に投げます。
    class UnknownModelError < StandardError; end

    # 整形に必要な内容が下書きに無い場合に投げます。
    class InvalidDraftError < StandardError; end

    # 実装していない約束を呼ばれた場合に投げます。
    class NotImplementedError < StandardError; end

    # 整形の結果です。
    #
    # **モデルが受け取れる形に整った、最終の出力です。**
    # `negative_prompt` は、打ち消しの欄を持つモデルだけが値を持ちます。
    Formatted = Struct.new(:main_prompt, :negative_prompt, :parameters, keyword_init: true) do
      # 打ち消しの欄を持つかどうかを返します。
      def negative?
        !negative_prompt.nil?
      end

      def to_h
        { main_prompt: main_prompt, negative_prompt: negative_prompt, parameters: parameters }
      end
    end

    class << self
      # 生成モデルに対応するアダプタを返します。
      #
      # **知らないモデルは、その場で失敗させます。**
      # @return [ModelAdapter]
      def for(target_model)
        adapter = registry[target_model]
        return adapter.new if adapter

        raise UnknownModelError,
              "対応していない生成モデルです: #{target_model.inspect}" # 開発者向け
      end

      # 対応している生成モデルです。
      def supported_models
        registry.keys
      end

      private

      # **仕様が定める 4 系統をすべて持ちます**（requirements.md 4.1）。
      def registry
        {
          'midjourney' => MidjourneyAdapter,
          'dalle' => DalleAdapter,
          'stable_diffusion' => StableDiffusionAdapter,
          'nano_banana' => NanoBananaAdapter
        }
      end
    end

    # 下書きを、そのモデルの記法へ整えます。
    # @return [Formatted]
    def format(draft)
      ensure_draft!(draft)

      Formatted.new(
        main_prompt: main_prompt_for(draft),
        negative_prompt: negative_prompt_for(draft),
        parameters: parameters_for(draft)
      )
    end

    # このアダプタが打ち消しの欄を持つかどうかを返します。
    def negative_prompt?
      raise NotImplementedError, "#{self.class} が negative_prompt? を実装していません" # 開発者向け
    end

    private

    # **素材が 1 件も無い下書きを整形しません。**
    # 空の指示を生成モデルへ渡すと、何が出るか決まりません。
    def ensure_draft!(draft)
      unless draft.respond_to?(:main_terms) && draft.respond_to?(:negative_terms)
        raise InvalidDraftError, "下書きを渡してください: #{draft.class}" # 開発者向け
      end

      return if draft.main_terms.any?

      raise InvalidDraftError, '素材がありません。' # 開発者向け
    end

    def main_prompt_for(_draft)
      raise NotImplementedError, "#{self.class} が main_prompt_for を実装していません" # 開発者向け
    end

    def negative_prompt_for(_draft)
      raise NotImplementedError, "#{self.class} が negative_prompt_for を実装していません" # 開発者向け
    end

    def parameters_for(_draft)
      raise NotImplementedError, "#{self.class} が parameters_for を実装していません" # 開発者向け
    end

    # 下書きの入力から値を取り出します。**欠けていれば失敗させます。**
    def input_value(draft, key)
      value = draft.input.is_a?(Hash) ? draft.input[key] : nil
      return value if value.is_a?(String) && !value.strip.empty?

      raise InvalidDraftError, "下書きに #{key} がありません: #{value.inspect}" # 開発者向け
    end
  end
end
