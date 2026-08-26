# frozen_string_literal: true

module Metrics
  # 測定の記録を、本業の結果から切り離す入口です（requirements.md 7.1）。
  #
  # **測定は本業の脇にあるものです。本業の失敗の種類を書き換えません。**
  #
  # 直に `Recorder` を呼ぶと、次の 2 つが起きます（PR #164 のレビューで実測されました）。
  #
  #   1. 上限到達をお伝えする例外が、記録の失敗に置き換わります。
  #      利用者は「本日の枠を使い切りました。次は◯時に戻ります」ではなく、
  #      **理由の分からない失敗**を受け取ります。
  #   2. 枠を返したあとで記録が失敗すると、**返還は済んでいるのに呼び出す側は
  #      失敗を受け取ります。** やり直すと予約中の記録がもう無く、
  #      やり直しの効かない状態が残ります。
  #
  # **握りつぶしません。** 記録の失敗そのものを、追える形で残します。
  # 残すのは軸の名前と例外の種別だけです。
  #
  # **受け止めるのは、記録の置き場の失敗だけです。** 定義に無い軸を渡した
  # 誤りは受け止めません。**それは書き間違いであり、失敗させるべきものです。**
  #
  # **呼び出す側がトランザクションで包むと、記録は巻き戻ります。**
  # `Recorder` は自前のトランザクションを持ちません。**包んで呼ばないでください。**
  # 上限到達は、まさに外側のトランザクションが巻き戻る場面で起きます。
  class SideChannel
    # 記録の置き場の失敗です。**ここに無い失敗は、そのまま外へ出します。**
    STORE_FAILURES = [ActiveRecord::ActiveRecordError].freeze

    class << self
      # 軸の件数を 1 つ増やします。**失敗しても、呼び出す側へ投げません。**
      # @return [MetricEvent, nil] 記録できなかった場合は nil です
      def record(axis, now: Time.current)
        Recorder.record(axis, now: now)
      rescue *STORE_FAILURES => e
        failed(axis, e)
      end

      private

      # **失敗を残します。** 記録できなかったことが、後から追えます。
      def failed(axis, error)
        Trace.step('metrics.record_failed', axis: axis, error: error.class.name) { nil }
      end
    end
  end
end
