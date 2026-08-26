# frozen_string_literal: true

module Metrics
  # 測定軸の記録です（requirements.md 7.1）。
  #
  # **仕様が定める軸だけを扱います。** 定義に無い指標を増やしません。
  # 知らない軸を渡されたら、その場で失敗させます。
  #
  # **個人を特定できる形で記録しません。** 残すのは、軸の名前・クォータ日・
  # 件数だけです。**利用者の識別子を渡す入口を持ちません。**
  #
  # **数え上げは、データベースの一意制約に守らせます。** 同じ日・同じ軸へ
  # 並列に記録しても、行が 2 つできません。
  #
  # **自前のトランザクションを持ちません。** 呼び出す側がトランザクションで
  # 包むと、**その巻き戻しに巻き込まれて記録が消えます**（PR #164 のレビューで
  # 実測されました）。**包んで呼ばないでください。**
  #
  # **本業の途中から直に呼ばないでください。** 記録が失敗すると、本業の失敗の
  # 種類が書き換わります。本業から呼ぶ場合は `Metrics::SideChannel` を通します。
  class Recorder
    # 定義に無い軸を渡された場合に投げます。
    class UnknownAxisError < StandardError; end

    class << self
      # その時刻のクォータ日で、軸の件数を 1 つ増やします。
      # @return [MetricEvent]
      def record(axis, now: Time.current)
        ensure_axis!(axis)
        occurred_on = Quota::QuotaDay.of(now)

        Trace.step('metrics.recorded', axis: axis, occurred_on: occurred_on) do
          increment(axis, occurred_on)
        end
      end

      # その軸の、期間内の件数を返します。
      # @return [Integer]
      def total(axis, from:, to:)
        ensure_axis!(axis)

        MetricEvent.for_axis(axis).between(from, to).sum(:occurrences)
      end

      private

      # **並列に記録しても、行が 2 つできません。**
      #
      # **数え上げは、データベースの側で 1 文で行います。**
      # 読んでから足して書くと、同時に呼ばれたときに数が合いません。
      # 行に錠をかける形も試しましたが、**呼び出す側が例外の処理の途中に
      # あるとき、入れ子のトランザクションが中断状態になり、記録そのものが
      # 落ちました**（issue #63 で実測しました）。1 文なら、その心配がありません。
      #
      # **検証を通しません。** 軸の名前は `ensure_axis!` が先に検め、
      # 日と軸の重なりはデータベースの一意索引が止めます。
      def increment(axis, occurred_on)
        MetricEvent.upsert( # rubocop:disable Rails/SkipsModelValidations
          { axis: axis, occurred_on: occurred_on, occurrences: 1 },
          unique_by: %i[axis occurred_on],
          on_duplicate: Arel.sql('occurrences = metric_events.occurrences + 1')
        )

        MetricEvent.find_by!(axis: axis, occurred_on: occurred_on)
      end

      # **定義に無い軸を記録しません。** 増やす場合は requirements.md 7.1 を先に改めます。
      def ensure_axis!(axis)
        return if MetricEvent::AXES.include?(axis)

        raise UnknownAxisError, "定義に無い測定軸です: #{axis.inspect}" # 開発者向け
      end
    end
  end
end
