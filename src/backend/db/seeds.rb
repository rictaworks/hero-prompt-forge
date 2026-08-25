# frozen_string_literal: true

# 初期の規則辞書です。
#
# 内容は requirements.md 4.1・4.2 に基づきます。
# 公開済みの版は書き換えないため、内容を変える場合は新しい版を作ります。
# 何度実行しても同じ結果になります。

anti_ai_rules = {
  # メインプロンプトから排除する語です。
  'forbidden_terms' => [
    'purple to teal gradient',
    'neon gradient background',
    'floating 3d shapes',
    'abstract floating objects',
    'hyper saturated',
    'oversaturated colors',
    'lens flare everywhere',
    'glowing particles'
  ],
  # 排除する語に対応して必ず注入する語です。
  'negative_prompt_terms' => [
    'purple teal gradient',
    'neon gradient',
    'floating 3d objects',
    'meaningless props',
    'oversaturation',
    'excessive bokeh',
    'deformed hands',
    'extra fingers',
    'distorted face',
    'text artifacts',
    'watermark'
  ],
  # 既定で避ける構図です。利用者が明示した場合のみ許します。
  'avoided_compositions' => [
    'large frontal face close-up'
  ]
}.freeze

style_spec_rules = {
  'photoreal' => {
    'required' => %w[lens_mm key_light fill_light rim_light depth_of_field],
    'lens_mm' => [24, 35, 50, 85],
    'lighting' => {
      'key_light' => 'soft key light from a north-facing window',
      'fill_light' => 'bounced fill from a white wall',
      'rim_light' => 'subtle rim light separating the subject'
    },
    'depth_of_field' => 'shallow depth of field on the subject plane',
    'person_safety' => %w[back_view cropped_hands distant_figure]
  },
  'illustration' => {
    'required' => %w[line_quality shading palette],
    'line_quality' => 'clean tapered linework',
    'shading' => 'flat shading with limited gradients',
    'palette' => 'restrained palette of three to four colors'
  },
  'three_d' => {
    'required' => %w[material rendering lighting],
    'material' => 'physically based materials with visible surface grain',
    'rendering' => 'path traced rendering, neutral tone mapping',
    'lighting' => 'single dominant light source with soft shadows'
  },
  'abstract' => {
    'required' => %w[geometry motion palette],
    'geometry' => 'geometry derived from the brand mark',
    'motion' => 'implied motion along a single axis',
    'palette' => 'two brand colors plus one neutral'
  }
}.freeze

industry_defaults = {
  'saas' => { 'tone' => 'trust', 'style_family' => 'photoreal' },
  'restaurant' => { 'tone' => 'warmth', 'style_family' => 'photoreal' },
  'medical' => { 'tone' => 'trust', 'style_family' => 'photoreal' },
  'education' => { 'tone' => 'friendly', 'style_family' => 'illustration' },
  'real_estate' => { 'tone' => 'trust', 'style_family' => 'photoreal' },
  'manufacturing' => { 'tone' => 'advanced', 'style_family' => 'photoreal' },
  'professional_services' => { 'tone' => 'trust', 'style_family' => 'photoreal' },
  'ecommerce' => { 'tone' => 'friendly', 'style_family' => 'photoreal' },
  'beauty' => { 'tone' => 'premium', 'style_family' => 'photoreal' },
  'other' => { 'tone' => 'minimal', 'style_family' => 'photoreal' }
}.freeze

initial_version = 'v2026.08.1'

dictionary = RuleDictionary.find_or_initialize_by(version: initial_version)

if dictionary.new_record?
  dictionary.assign_attributes(
    anti_ai_rules: anti_ai_rules,
    style_spec_rules: style_spec_rules,
    industry_defaults: industry_defaults
  )
  dictionary.save!
  dictionary.publish!
  Rails.logger.info("規則辞書 #{initial_version} を作成し、公開しました。") # 開発者向け
else
  Rails.logger.info("規則辞書 #{initial_version} はすでに存在します。") # 開発者向け
end
