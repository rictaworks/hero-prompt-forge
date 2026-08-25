# frozen_string_literal: true

# 評価メモです。
#
# 生成画像を実際に作った結果の所感を記録し、次回の条件調整に用います。
class CreateEvaluationNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :evaluation_notes do |t|
      # 1つの案につき1件の評価メモを持ちます。
      # references が作る索引をそのまま一意にします（索引を二重に作らないためです）。
      t.references :prompt_output, null: false, foreign_key: true,
                                   index: { unique: true }
      t.integer :rating, comment: '5段階の評価。未評価は空です'
      t.text :memo, comment: '所感'

      t.timestamps
    end
  end
end
