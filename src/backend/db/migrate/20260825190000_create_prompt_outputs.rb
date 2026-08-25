# frozen_string_literal: true

# プロンプトパッケージの1案です。
#
# 1つの生成リクエストにつき、構図の異なる3案を保持します。
class CreatePromptOutputs < ActiveRecord::Migration[8.1]
  def change
    create_table :prompt_outputs do |t|
      t.references :prompt_request, null: false, foreign_key: true
      t.integer :variation_no, null: false, comment: '1〜3'
      t.string :composition_type, null: false, comment: '被写体主導／環境主導／抽象背景'
      t.text :main_prompt, null: false, comment: 'メインプロンプト'
      t.text :negative_prompt, comment: 'ネガティブプロンプト。対応しないモデルでは空です'
      t.jsonb :parameters, null: false, default: {}, comment: '推奨パラメータ'
      t.text :art_direction_note, null: false, comment: 'アートディレクションノート'

      t.timestamps
    end

    # 同じリクエストで同じ番号を二重に持てないようにします。
    add_index :prompt_outputs, %i[prompt_request_id variation_no], unique: true
  end
end
