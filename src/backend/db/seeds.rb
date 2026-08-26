# frozen_string_literal: true

# 初期の規則辞書です。
#
# 中身は `config/rule_dictionary/initial.yml` にあります。**この手順書へ
# 直接書きません。** 中身が仕様どおりかをテストから確かめられるようにするためです。
#
# 公開済みの版は書き換えないため、内容を変える場合は新しい版を作ります。
# 何度実行しても同じ結果になります。

initial_version = InitialRuleDictionary.version

dictionary = RuleDictionary.find_or_initialize_by(version: initial_version)

if dictionary.new_record?
  dictionary.assign_attributes(
    anti_ai_rules: InitialRuleDictionary.anti_ai_rules,
    style_spec_rules: InitialRuleDictionary.style_spec_rules,
    industry_defaults: InitialRuleDictionary.industry_defaults
  )
  dictionary.save!
  dictionary.publish!
  Rails.logger.info("規則辞書 #{initial_version} を作成し、公開しました。") # 開発者向け
else
  Rails.logger.info("規則辞書 #{initial_version} はすでに存在します。") # 開発者向け
end
