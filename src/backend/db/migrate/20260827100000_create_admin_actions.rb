# frozen_string_literal: true

# 管理者が行った操作の記録です（requirements.md 4.4、issue #66、#67）。
#
# **実施者と日時を残します。** クォータの手動リセットと手動再判定は、
# 利用者の状態を管理者が直接変える操作です。**誰が、いつ、誰に対して
# 行ったのかが残らないと、後から辿れません。**
#
# **実施者は、管理画面の資格情報の利用者名です。** 管理画面は BASIC 認証で、
# 一般の利用者の仕組みとは別です（requirements.md 5.2）。
#
# **合言葉を残しません。** 残すのは利用者名だけです。
#
# **対象の利用者は識別子で持ちます。** 表示名を写し取ると、名前が変わった
# ときに記録と食い違います。
class CreateAdminActions < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_actions do |t|
      t.string :actor, null: false, comment: '実施者（管理画面の利用者名）'
      t.string :action, null: false, comment: '操作の種別'
      t.bigint :user_id, comment: '対象の利用者。対象が無い操作では空です'
      t.jsonb :details, null: false, default: {}, comment: '補足。秘匿値を入れません'
      t.timestamps
    end

    add_index :admin_actions, %i[created_at]
    add_index :admin_actions, %i[user_id created_at]
    add_foreign_key :admin_actions, :users
  end
end
