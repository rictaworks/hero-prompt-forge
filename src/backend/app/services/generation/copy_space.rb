# frozen_string_literal: true

module Generation
  # コピースペースの構図規定です（requirements.md 4.1 の 4、4.2）。
  #
  # ヒーローイメージには、見出しと CTA ボタンを重ねる余白が要ります。
  # **コピースペースを持たない案を出しません。** 4.2 が明示的に禁じています。
  #
  # 指定された位置に基づき、次の 4 つを **1 件 1 指示** で足します。
  #
  #   1. 余白そのもの（三分割構図のどの帯を空けるか）
  #   2. 被写体を置く場所（余白と重ならない側の三分割の交点）
  #   3. 視線誘導（**余白側へ導きつつ、余白へ入り込まない形**）
  #   4. 余白側を静かに保つ指定（文字の可読性を守ります）
  #
  # **被写体と視線誘導が余白側と競合しない配置**を求める要件を、この 4 つで
  # 満たします。被写体は反対側へ寄せ、余白の帯は細部と明暗を抑えます。
  #
  # アスペクト比の指示も足します。横に長いほど寄せる余地が変わるため、
  # 同じ余白の指定でも画づくりが変わります。
  #
  # **素材は英語で作ります。打ち消しの言い回し（`no ...`）を作りません。**
  # スタイルの仕様化（issue #41）と同じ決まりです。
  class CopySpace
    # 下書きにコピースペース位置が入っていない場合に投げます。
    class MissingPositionError < StandardError; end

    # 下書きにアスペクト比が入っていない場合に投げます。
    class MissingAspectRatioError < StandardError; end

    # 定義が読めない、または内容が足りない場合に投げます。
    InvalidDefinitionError = CopySpaceRules::InvalidDefinitionError

    # 定義されていない位置・アスペクト比を渡された場合に投げます。
    UnknownPositionError = CopySpaceRules::UnknownPositionError
    UnknownAspectRatioError = CopySpaceRules::UnknownAspectRatioError

    # ノートに残す印です。文言ではなく記号で持ちます。
    NOTE_KIND = :copy_space_reserved

    # コピースペースの指示を足した下書きを返します。
    # @return [Draft]
    def apply(draft)
      position = position_of(draft)
      aspect_ratio = aspect_ratio_of(draft)
      instructions = CopySpaceRules.instructions_for(position)
      ratio_instruction = CopySpaceRules.aspect_ratio_instruction(aspect_ratio)

      traced(draft, position, aspect_ratio, instructions + [ratio_instruction])
    end

    # その下書きがコピースペースの指定を持っているかどうかを返します。
    #
    # **出力の直前に確かめるための入口です。** 4.2 は「コピースペースを
    # 持たないヒーローイメージ用プロンプトは出力しない」と定めています。
    def self.reserved?(draft)
      draft.notes.any? { |note| note[:kind] == NOTE_KIND }
    end

    private

    def traced(draft, position, aspect_ratio, instructions)
      Trace.step('generation.copy_space_applied',
                 position: position,
                 aspect_ratio: aspect_ratio,
                 instructions: instructions.size) do
        draft.add(
          main_terms: instructions,
          notes: [{ kind: NOTE_KIND, position: position, aspect_ratio: aspect_ratio }]
        )
      end
    end

    # **コピースペース位置は必ず決まっています。** 入力の正規化が既定値
    # （左）で補うため、ここへ届かないのは組み立ての誤りです。既定へ寄せず、
    # その場で失敗させます。寄せると、指定と違う位置に余白ができます。
    def position_of(draft)
      value = draft.input.is_a?(Hash) ? draft.input[:copy_space_position] : nil
      return value if value.is_a?(String) && !value.strip.empty?

      raise MissingPositionError,
            "下書きにコピースペース位置がありません: #{value.inspect}" # 開発者向け
    end

    def aspect_ratio_of(draft)
      value = draft.input.is_a?(Hash) ? draft.input[:aspect_ratio] : nil
      return value if value.is_a?(String) && !value.strip.empty?

      raise MissingAspectRatioError,
            "下書きにアスペクト比がありません: #{value.inspect}" # 開発者向け
    end
  end
end
