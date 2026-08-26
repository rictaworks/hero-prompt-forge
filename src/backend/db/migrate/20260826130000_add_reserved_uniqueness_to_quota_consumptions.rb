# frozen_string_literal: true

# 1つの生成リクエストに対して、有効な予約を1件だけにします。
#
# 予約を生成リクエストから引くとき、同じリクエストを指す予約が複数あると
# どれが返るか決まりません。日をまたいで再実行した場合に、決着が前日の
# 返還済みの記録へ当たり、当日の枠が戻らなくなります（issue #127）。
#
# 返還済み・確定済みは履歴として複数残ります。**予約中だけを一意にします。**
class AddReservedUniquenessToQuotaConsumptions < ActiveRecord::Migration[8.1]
  def change
    add_index :quota_consumptions, :prompt_request_id,
              unique: true,
              where: "status = 'reserved' AND prompt_request_id IS NOT NULL",
              name: 'index_quota_consumptions_on_reserved_prompt_request'
  end
end
