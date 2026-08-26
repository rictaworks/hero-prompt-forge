# frozen_string_literal: true

# 生成に使う設定ファイルを、起動時に読み込んで検めます。
#
# **遅延読み込みのままだと、壊れていることに最初の生成まで気づけません**
# （issue #148）。お客さまがお申し込みになった瞬間に落ちます。
# **起動時に落とせば、デプロイの段階で気づけます。**
#
# **開発中の再読み込みでは走らせません。** 編集のたびに読み直すと、
# 変更が反映されない古い定義を掴んだまま動きます。
Rails.application.config.to_prepare do
  next unless Rails.application.config.eager_load

  Generation::WordForms.reset!
  Generation::WordForms.spelling_variants
end
