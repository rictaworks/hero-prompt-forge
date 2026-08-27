# frozen_string_literal: true

require 'rails_helper'

# 入力条件で選べる値の契約です（`SPEC/api/README.md`、PR #174 のレビュー・要修正 5）。
#
# **画面とバックエンドは、同じ表を実装します。** 片方だけを増やすと、
# 画面では選べるのに投入で弾かれます（またはその逆になります）。
# **一致していることを、ここで検めます。**
#
# **画面の側は TypeScript です。** 定義の並びを読み取って比べます。
# 書き方が変わったら、この検査が「読み取れません」で落ちます。**黙って
# 素通りしません。**
RSpec.describe '入力条件の契約' do
  # 画面側の定義の置き場です。
  def frontend_choices_path
    'src/frontend/src/types/resources.ts'
  end

  # 画面側の定義を読み取ります。**読み取れなければ失敗させます。**
  def frontend_values(name)
    source = Rails.root.join('../..', frontend_choices_path).read
    match = source.match(/export const #{name} = \[(.*?)\] as const;/m)
    raise "画面側の定義を読み取れません: #{name}" if match.nil? # 開発者向け

    match[1].scan(/"([^"]+)"/).flatten
  end

  # 画面側の名前と、バックエンド側の値の対応です。
  # **`describe` の中で数え上げますので、定数ではなく、その場の値で書きます。**
  {
    'INDUSTRIES' => 'INDUSTRIES', 'STYLE_FAMILIES' => 'STYLE_FAMILIES',
    'TARGET_MODELS' => 'TARGET_MODELS', 'BRAND_TONES' => 'BRAND_TONES',
    'COPY_SPACE_POSITIONS' => 'COPY_SPACE_POSITIONS', 'ASPECT_RATIOS' => 'ASPECT_RATIOS'
  }.each_key do |name|
    it "#{name}：画面とバックエンドで一致します" do
      expect(frontend_values(name)).to eq(Generation::InputChoices.const_get(name))
    end
  end

  it '既定値が画面と一致します' do
    source = Rails.root.join('../..', frontend_choices_path).read

    expect(source).to include(
      %(export const DEFAULT_COPY_SPACE_POSITION = "#{Generation::InputChoices::DEFAULT_COPY_SPACE_POSITION}";)
    ).and include(
      %(export const DEFAULT_ASPECT_RATIO = "#{Generation::InputChoices::DEFAULT_ASPECT_RATIO}";)
    )
  end

  it '上限が画面と一致します' do
    source = Rails.root.join('../..', frontend_choices_path).read

    expect(source).to include(
      "export const MAX_SERVICE_SUMMARY_LENGTH = #{Generation::InputChoices::MAX_SERVICE_SUMMARY_LENGTH};"
    ).and include(
      "export const MAX_BRAND_COLORS = #{Generation::InputChoices::MAX_BRAND_COLORS};"
    )
  end

  # **読み取りそのものが働いていることを確かめます。**
  it '読み取れない名前は失敗させます' do
    expect { frontend_values('NOT_DEFINED_ANYWHERE') }.to raise_error(RuntimeError)
  end
end
