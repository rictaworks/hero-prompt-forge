# frozen_string_literal: true

module Metrics
  # 利用状況の集計です（requirements.md 7.1、issue #68）。
  #
  # **仕様が定める軸だけを扱います。** 定義に無い指標を増やしません。
  #
  # **個人を特定できる形で返しません。** 利用者ごとの件数は、名前も識別子も
  # 添えずに**分布**（利用者数・合計・最大・中央値）として返します。
  #
  # **記録していない軸を作り出しません。**
  #
  #   - バリエーション 3 案のうちコピーされた案の分布：**まだ記録していません**
  #   - 稼働率：外形監視の受け持ちです（requirements.md 7.3）
  #
  # 返す形は、画面が並べ替えずにそのまま描ける形にします。
  class UsageSummary
    # 集計の対象にしない状態です。**差し戻しは生成の要求として数えません。**
    # ジョブ投入の前に決まり、枠も使いません（requirements.md 4.4）。
    EXCLUDED_STATUSES = [PromptRequest::REJECTED].freeze

    # 成果物を提供した状態です。
    DELIVERED = PromptRequest::DELIVERED_STATUSES

    # 利用者ごとの件数の分布です。**名前も識別子も持ちません。**
    #
    # **`max` という名前を使いません。** `Struct` が持つ `max` を覆い隠します
    # （書き間違えたときに、別のものが静かに返ります）。
    Distribution = Struct.new(:users, :total, :largest, :median, keyword_init: true) do
      def to_h
        { users: users, total: total, max: largest, median: median }
      end
    end

    # @return [Hash]
    def call
      Trace.step('metrics.usage_summary') do
        {
          requests: requests_summary,
          degraded: degraded_summary,
          evaluation: evaluation_summary,
          regeneration: regeneration_summary,
          quota: quota_summary
        }
      end
    end

    private

    # 集計の母数です。**差し戻しを含みません。**
    def counted
      PromptRequest.where.not(status: EXCLUDED_STATUSES)
    end

    # 生成リクエスト数（業種別・スタイル別・モデル別・利用者ごとの分布）です。
    def requests_summary
      {
        total: counted.count,
        by_industry: counted.group("inputs->>'industry'").count,
        by_style_family: counted.group("inputs->>'style_family'").count,
        by_target_model: counted.group(:target_model).count,
        by_user: per_user_distribution
      }
    end

    # **利用者ごとの件数は、分布だけを返します。**
    # 誰が何回使ったかを、この画面から読み取れないようにします。
    def per_user_distribution
      counts = counted.joins(:project).group('projects.user_id').count.values.sort

      Distribution.new(users: counts.size, total: counts.sum,
                       largest: counts.max || 0, median: median(counts)).to_h
    end

    def median(values)
      return 0 if values.empty?

      middle = values.size / 2
      values.size.odd? ? values[middle] : ((values[middle - 1] + values[middle]) / 2.0).round(1)
    end

    # 縮退モードでの生成比率です。
    def degraded_summary
      delivered = counted.where(status: DELIVERED)
      total = delivered.count
      degraded = delivered.where(degraded: true).count

      { delivered: total, degraded: degraded, ratio: ratio(degraded, total) }
    end

    # プロンプト評価メモの記録率と評価傾向です。
    def evaluation_summary
      outputs = PromptOutput.count
      notes = EvaluationNote.count

      { outputs: outputs, notes: notes, ratio: ratio(notes, outputs),
        by_rating: EvaluationNote.where.not(rating: nil).group(:rating).count }
    end

    # 再生成率（同一プロジェクトでの条件変更回数）です。
    #
    # **1 件目は再生成ではありません。** 2 件目以降を再生成として数えます。
    def regeneration_summary
      per_project = counted.group(:project_id).count.values
      projects = per_project.size
      total = per_project.sum
      regenerated = per_project.sum { |count| count - 1 }

      { projects: projects, requests: total, regenerations: regenerated,
        ratio: ratio(regenerated, total) }
    end

    # 上限到達の発生数と、クォータ返還の発生数です。
    def quota_summary
      {
        exhausted: MetricEvent.for_axis(MetricEvent::QUOTA_EXHAUSTED).sum(:occurrences),
        reclaimed: MetricEvent.for_axis(MetricEvent::QUOTA_RECLAIMED).sum(:occurrences)
      }
    end

    # **母数が 0 のときは 0 を返します。** 0 で割りません。
    def ratio(part, total)
      return 0.0 if total.zero?

      ((part.to_f / total) * 100).round(1)
    end
  end
end
