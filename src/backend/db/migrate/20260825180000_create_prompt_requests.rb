# frozen_string_literal: true

# 生成リクエストです。
#
# 状態は requirements.md 12.1 の遷移に従います。
class CreatePromptRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :prompt_requests do |t|
      t.references :project, null: false, foreign_key: true
      t.jsonb :inputs, null: false, default: {}, comment: '正規化済み入力'
      t.string :target_model, null: false, comment: '生成モデル'
      t.string :status, null: false, default: 'draft', comment: '状態遷移図を参照'
      t.string :dictionary_version, comment: '適用した規則辞書の版'
      t.boolean :degraded, null: false, default: false, comment: '縮退モードで生成したか'
      t.text :rejection_reason, comment: '差し戻した理由'

      t.timestamps
    end

    add_index :prompt_requests, %i[project_id created_at]
    add_index :prompt_requests, :status
  end
end
