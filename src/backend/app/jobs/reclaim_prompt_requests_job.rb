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

  # **同じ場所で毎回落ちる行を、際限なく拾い続けたと見なす理由です**
  # （issue #181）。`record_failure` の理由（`reason_for`）は種別だけを
  # 残すため、この名前がそのまま `rejection_reason` に記録されます。
  # 利用者の入力は含みません。
  class AbandonedError < StandardError; end

  # 1 回で投入する上限です。**次の回で続きを拾います。**
  BATCH_SIZE = 50

  # 置き去りと見なすまでの時間です。**`GeneratePromptJob` と同じ値です。**
  # **書き写しません。** 片方だけを直すと、拾い直しが黙って発火しなくなります。
  STALE_AFTER = GeneratePromptJob::STALE_AFTER

  # **拾い直しに上限を設けます**（issue #181・PR #176 のレビューより）。
  #
  # 働き手が同じ理由で毎回落ちる行（例：メモリ不足）は、`generating` の
  # まま残り続けます。上限が無いと、5 分ごとに際限なく投入され続け、
  # 1 回ごとに有償の呼び出しがかかります。
  #
  # **回数を数える列は増やしません。** 掴み手の印と同じく移行が要りますし、
  # このリポジトリには既にクォータの日境界（`Quota::QuotaDay`、
  # requirements.md 4.4）があります。**生成リクエストを作った時点の
  # クォータ日と、いまのクォータ日がずれていれば、日をまたいでも組み立てに
  # 一度も進めていない行**と見なし、打ち切ります（失敗として記録し、
  # 枠を返します）。対象は `generating` のまま動きが無い行だけです。
  # 決着だけが残っている行（`awaiting_settlement?` 側）は、組み立てを
  # 終えていますので対象外です。
  def perform
    stale = stale_ids
    abandoned = abandoned_ids(stale)
    cut_off!(abandoned) if abandoned.any?

    ids = ((stale - abandoned) + unsettled_ids).uniq.first(BATCH_SIZE)

    Trace.step('jobs.reclaim_prompt_requests', candidates: ids.size, abandoned: abandoned.size) do
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

  # **日をまたいでも組み立てに進めていない行です。** 生成リクエストを
  # 作った時点のクォータ日と、いまのクォータ日を比べます。
  def abandoned_ids(ids)
    return [] if ids.empty?

    today = Quota::QuotaDay.of(Time.current)
    PromptRequest.where(id: ids)
                 .reject { |request| Quota::QuotaDay.of(request.created_at) == today }
                 .map(&:id)
  end

  # **失敗として打ち切ります。** `GeneratePromptJob` の失敗記録
  # （`record_failure`）をそのまま通します。行の遷移・理由の記録・
  # クォータの返還を、この持ち場で書き写しません。
  def cut_off!(ids)
    ids.each { |id| GeneratePromptJob.new(id).record_failure(AbandonedError.new) }
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
