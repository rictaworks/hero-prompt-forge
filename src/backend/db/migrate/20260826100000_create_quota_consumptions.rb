# frozen_string_literal: true

# クォータの消費です。
#
# 1アカウント1日1回の制限を、**データベースの一意制約で担保します**
# （requirements.md 4.4）。検証だけに頼ると、二重送信や並列投入で
# 同じ日に2件通る余地が残ります。
class CreateQuotaConsumptions < ActiveRecord::Migration[8.1]
  def change
    create_table :quota_consumptions do |t|
      t.references :user, null: false, foreign_key: true
      t.date :quota_day, null: false, comment: 'JST 03:00 を境界とする日付'
      t.references :prompt_request, foreign_key: true,
                                    comment: '予約の対象。予約時点では未作成のため後から結び付けます'
      t.string :status, null: false, default: 'reserved', comment: 'reserved / confirmed / refunded'
      t.boolean :reset_by_admin, null: false, default: false, comment: '管理者による手動リセットか'

      t.timestamps
    end

    # 1アカウント1日1回の担保です。
    add_index :quota_consumptions, %i[user_id quota_day], unique: true
    add_index :quota_consumptions, %i[quota_day status]
  end
end
