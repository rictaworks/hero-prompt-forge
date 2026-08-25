# frozen_string_literal: true

# 利用者です。
#
# 保持する個人関連情報は X のユーザーID（識別子）と表示名のみです。
# メールアドレス・住所・電話番号を取得しません。
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :x_user_id, null: false, comment: 'X の数値のユーザーID'
      t.string :display_name, null: false, comment: 'X の表示名'
      t.string :plan, null: false, default: 'unverified', comment: 'アクセス権を表す単一項目'

      t.timestamps
    end

    add_index :users, :x_user_id, unique: true
  end
end
