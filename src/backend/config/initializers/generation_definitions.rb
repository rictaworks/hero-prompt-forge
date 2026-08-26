# frozen_string_literal: true

# 生成に使う設定ファイルを、起動時に読み込んで検めます。
#
# **遅延読み込みのままだと、壊れていることに最初の生成まで気づけません**
# （issue #148）。お客さまがお申し込みになった瞬間に落ちます。
# **起動時に落とせば、デプロイの段階で気づけます。**
#
# **必須の項目を足したら、この一覧へも足してください。** 足さないと、
# その項目が欠けても最初の生成まで気づけません（PR #157 のレビューより）。
#
# **開発中の再読み込みでは走らせません。** 編集のたびに読み直すと、
# 変更が反映されない古い定義を掴んだまま動きます。
Rails.application.config.to_prepare do
  next unless Rails.application.config.eager_load

  # 語の形の対応表です（issue #136）。
  Generation::WordFormsTable.load

  # 固有名詞の手がかりと、会社名のうしろに付く語です（issue #44、#153）。
  Generation::ProperNoun.load_rules
  Generation::ProperNoun.load_suffix_readings
  Generation::ProperNoun.load_attribute_words

  # 禁止入力の検出規則です（requirements.md 4.1 の 1）。
  Generation::ForbiddenDetector.new
end
