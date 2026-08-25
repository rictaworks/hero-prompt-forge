# frozen_string_literal: true

# プリセットです。
#
# 入力条件の組み合わせを名前付きで保存し、呼び出します。
class CreatePresets < ActiveRecord::Migration[8.1]
  def change
    create_table :presets do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false, comment: 'プリセット名'
      t.jsonb :input_conditions, null: false, default: {}, comment: '入力条件の組み合わせ'

      t.timestamps
    end

    # 同じ利用者が同じ名前を二重に持てないようにします。
    add_index :presets, %i[user_id name], unique: true
  end
end
