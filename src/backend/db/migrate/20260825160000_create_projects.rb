# frozen_string_literal: true

# プロジェクトです。
#
# サイト単位で入力条件を保存し、再生成・条件変更に用います。
class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, comment: 'サイト名（任意）'
      t.string :industry, null: false, comment: '業種'
      t.string :style_family, null: false, comment: 'スタイル系統'
      t.jsonb :brand_settings, null: false, default: {}, comment: 'トーン・カラー等'

      t.timestamps
    end

    add_index :projects, %i[user_id created_at]
  end
end
