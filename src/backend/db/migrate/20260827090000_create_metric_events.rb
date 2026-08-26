# frozen_string_literal: true

# 測定軸の記録です（requirements.md 7.1）。
#
# **個人を特定できる形で記録しません。** 残すのは、
# **軸の名前・クォータ日・件数**だけです。利用者の識別子を持ちません。
#
# **1 行を数え上げる形にします。** 出来事ごとに 1 行を作ると、
# 行数が利用者数と生成回数に比例して増えます。**集計の対象は件数だけ**ですので、
# 日と軸で 1 行にまとめます。
class CreateMetricEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :metric_events do |t|
      t.string :axis, null: false, comment: '測定軸の名前（requirements.md 7.1）'
      t.date :occurred_on, null: false, comment: 'JST 03:00 を境界とするクォータ日'
      t.integer :count, null: false, default: 0, comment: 'その日の件数'

      t.timestamps
    end

    # **軸と日で 1 行です。** 同じ組み合わせを 2 行作りません。
    add_index :metric_events, %i[axis occurred_on], unique: true
  end
end
