# frozen_string_literal: true

# 置き去りの生成リクエストを拾い直します（issue #169）。
#
# **働き手（ジョブの実行係）が異常終了すると、生成リクエストが `generating` の
# まま取り残されます。** 待ち行列は仕事を戻しますが、戻ってくるのは投入時の
# 回数ですので、`GeneratePromptJob` はそれを投入し直しと見分けられません。
# **時間で見分けたうえで、定時に機会を作ります。**
#
# **定時に走らせる理由です。** 戻ってきた回が一度見送られると、その回は
# 正常終了しますので、**二度と投入されません。** 行は `generating`、枠は
# `reserved` のまま残ります。**残った `reserved` は、日をまたぐと予約そのものを
# 止めます**（`DanglingReservationError`）。その利用者は翌日以降も生成できません。
#
# **拾うのは 2 種類です。**
#
#   1. 動きが無いまま `STALE_AFTER` を越えた `generating` の行
#   2. 成果物を提供した／失敗として記録したのに、枠が `reserved` のまま残る行
#
# 2 は、確定・返還がひとまとまりの外で行われるためです。**片方だけを拾うと、
# 鏡像の側が取り残されます。**
#
# **投入するだけです。** 拾い直しの中身は `GeneratePromptJob` が持ちます。
# 判断を 2 か所へ分けません。
#
# **一度に投入する数に上限を置きます。** 取り残しが積み上がっていた場合に、
# 待ち行列を一度に埋めません。
class ReclaimPromptRequestsJob < ApplicationJob
  queue_as :default

  # 1 回で投入する上限です。**次の回で続きを拾います。**
  BATCH_SIZE = 50

  # 置き去りと見なすまでの時間です。**`GeneratePromptJob` と同じ値です。**
  # **書き写しません。** 片方だけを直すと、拾い直しが黙って発火しなくなります。
  STALE_AFTER = GeneratePromptJob::STALE_AFTER

  def perform
    ids = (stale_ids + unsettled_ids).uniq.first(BATCH_SIZE)

    Trace.step('jobs.reclaim_prompt_requests', candidates: ids.size) do
      ids.each { |id| GeneratePromptJob.perform_later(id) }
      ids.size
    end
  end

  private

  # 動きが無いまま置き去りになった行です。
  def stale_ids
    PromptRequest.where(status: PromptRequest::GENERATING)
                 .where(updated_at: ..STALE_AFTER.ago)
                 .order(:updated_at)
                 .limit(BATCH_SIZE)
                 .ids
  end

  # 決着だけが残っている行です。**枠が予約のまま残っています。**
  def unsettled_ids
    settled = PromptRequest::DELIVERED_STATUSES + [PromptRequest::FAILED]

    QuotaConsumption.outstanding
                    .where.not(prompt_request_id: nil)
                    .joins(:prompt_request)
                    .where(prompt_requests: { status: settled })
                    .order(:updated_at)
                    .limit(BATCH_SIZE)
                    .pluck(:prompt_request_id)
  end
end
