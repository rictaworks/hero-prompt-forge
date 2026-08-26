# frozen_string_literal: true

module Adapters
  # 本文へ入る素材の検めです（requirements.md 4.1 の 7）。
  #
  # **記法で特別な意味を持つ文字が混ざっていないかを確かめます。**
  # 一部の素材だけを検めると、残りから壊れます。Stable Diffusion 系では
  # 丸括弧そのものが強調ですので、`(soft light)` が混ざるだけで
  # 「最上位の指示にだけ重みを付ける」という判断が崩れます。Midjourney 系では
  # `--` が本文の途中に現れると、パラメータとして読まれます。
  # **例外もノートも残らないまま壊れます**（PR #154 の 2 回目のレビューより）。
  #
  # **規則辞書は管理画面から人が編集するデータです。** 混入は起こり得ます。
  #
  # **例外に素材そのものを出しません。** 素材には利用者由来の語が入り得ます。
  class TermGuard
    def initialize(pattern)
      @pattern = pattern
    end

    # @raise [ModelAdapter::UnsafeTermError] 記法を壊す文字が含まれる場合です
    def ensure_safe!(terms)
      return if pattern.nil?

      terms.each_with_index do |term, index|
        matched = term.scan(pattern).uniq
        next if matched.empty?

        raise ModelAdapter::UnsafeTermError,
              "素材に、この記法で意味を持つ文字が含まれます: #{index} 件目 / " \
              "#{matched.join(' ')}" # 開発者向け
      end
    end

    private

    attr_reader :pattern
  end
end
