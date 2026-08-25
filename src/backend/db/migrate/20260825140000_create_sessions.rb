# frozen_string_literal: true

# ログインの状態です。
#
# アプリケーションサーバーはステートレスに構成し、状態はデータベースに置きます
# （requirements.md 5.1）。どの実体が要求を受けても同じ結果になります。
class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false, comment: 'セッション識別子のハッシュ'
      t.datetime :expires_at, null: false, comment: '失効する時刻'
      t.datetime :revoked_at, comment: '取り消した時刻'

      t.timestamps
    end

    add_index :sessions, :token_digest, unique: true
    add_index :sessions, :expires_at
  end
end
