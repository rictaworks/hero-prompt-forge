# frozen_string_literal: true

# 測定軸の記録です（requirements.md 7.1）。
#
# **個人を特定できる形で記録しません。** 残すのは、
# **軸の名前・クォータ日・件数**の 3 つだけです。利用者の識別子を持ちません。
#
# **作成時刻・更新時刻を持ちません（`t.timestamps` を置きません）。**
# 作成時刻は「その日にはじめて起きた瞬間」をマイクロ秒で残します。
# `quota_consumptions`（利用者の識別子を持ちます）や記録と時刻で突き合わせると、
# **どなたかが絞り込めます。** 件数の少ない日ほど絞り込めます。
# 集計に必要なのは日と件数だけですので、時刻を持ちません。
#
# **`count` ではなく `occurrences` という名前にします。**
# `MetricEvent.count`（行数）と `MetricEvent#count`（件数）が同じ名前になると、
# 集計の画面で `.count` と書いたときに、静かに行数が返ります。
#
# **1 行を数え上げる形にします。** 出来事ごとに 1 行を作ると、
# 行数が利用者数と生成回数に比例して増えます。**集計の対象は件数だけ**ですので、
# 日と軸で 1 行にまとめます。
class CreateMetricEvents < ActiveRecord::Migration[8.1]
  def change
    # **時刻を持ちません。** 理由は上の説明のとおりです。
    create_table :metric_events do |t| # rubocop:disable Rails/CreateTableWithTimestamps
      t.string :axis, null: false, comment: '測定軸の名前（requirements.md 7.1）'
      t.date :occurred_on, null: false, comment: 'JST 03:00 を境界とするクォータ日'
      t.integer :occurrences, null: false, default: 0, comment: 'その日の件数'
    end

    # **軸と日で 1 行です。** 同じ組み合わせを 2 行作りません。
    add_index :metric_events, %i[axis occurred_on], unique: true
  end
end
