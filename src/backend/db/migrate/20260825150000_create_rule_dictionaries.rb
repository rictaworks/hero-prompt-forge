# frozen_string_literal: true

# 規則辞書です。
#
# アンチAIルック規則・スタイル仕様化規則・業種既定値を版で管理します。
# 生成に用いた版を記録できるようにするため、公開済みの版を書き換えず、
# 新しい版を作る運用とします。
class CreateRuleDictionaries < ActiveRecord::Migration[8.1]
  def change
    create_table :rule_dictionaries do |t|
      t.string :version, null: false, comment: '版の識別子'
      t.jsonb :anti_ai_rules, null: false, default: {}, comment: 'クリシェ排除規則'
      t.jsonb :style_spec_rules, null: false, default: {}, comment: 'スタイル仕様化規則'
      t.jsonb :industry_defaults, null: false, default: {}, comment: '業種既定値'
      t.datetime :published_at, comment: '公開した時刻。未公開は空です'

      t.timestamps
    end

    add_index :rule_dictionaries, :version, unique: true
    add_index :rule_dictionaries, :published_at
  end
end
