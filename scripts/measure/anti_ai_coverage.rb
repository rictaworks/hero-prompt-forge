# frozen_string_literal: true

# アンチAIルック規則の検出範囲を、両方向で測ります（issue #136）。
dictionary = RuleDictionary.new(
  version: 'vmeasure',
  anti_ai_rules: InitialRuleDictionary.anti_ai_rules
)
rules = Generation::AntiAiRules.new(dictionary)

keep = [
  '35mm lens', '24mm wide angle lens', '50mm lens', '85mm portrait lens',
  'soft key light from a north-facing window', 'bounced fill from a white wall',
  'subtle rim light separating the subject', 'shallow depth of field on the subject plane',
  'clean tapered linework', 'flat shading with limited gradients',
  'restrained palette of three to four colors', 'physically based materials',
  'path traced rendering, neutral tone mapping', 'single dominant light source with soft shadows',
  'geometry derived from the brand mark', 'implied motion along a single axis',
  'two brand colors plus one neutral', 'the subject seen from behind',
  'hands cropped out of the frame', 'a distant figure within the scene',
  'stealth startup founders', 'artisan coffee roastery', 'a heartfelt customer testimonial',
  'a factory line with metal parts', 'glowing laptop screen',
  'soft lens flare through a window', 'teal accent on a brand sign',
  'purple brand accent on a coffee cup', 'saturated red brand accent',
  '3d printed prototype on a workbench', 'a calm dental clinic waiting room',
  'a warm bakery counter at dawn', 'an architect reviewing blueprints',
  'a tidy law office bookshelf', 'a nurse walking a bright corridor',
  'a classroom with afternoon light', 'a workshop bench with hand tools',
  'a rooftop terrace at golden hour', 'a minimal product still life',
  'a quiet library reading room'
]

block = [
  'purple to teal gradient', 'purple to teal gradient background',
  'Purple To Teal Gradient', 'PURPLE TO TEAL GRADIENT', 'purple-to-teal gradient',
  'purple  to  teal  gradient', 'purple_to_teal_gradient',
  'neon gradient background', 'neon gradient backgrounds',
  'floating 3d shapes', 'floating 3d shape',
  'abstract floating objects', 'abstract floating object',
  'hyper saturated', 'hyper saturated colors',
  'oversaturated colors', 'oversaturated colours', 'over saturated colours',
  'lens flare everywhere', 'glowing particles', 'glowing particle',
  'glowing particle effects', 'glowing particles effect',
  'gradient from purple to teal', 'teal to purple gradient',
  'violet to teal gradient', 'neon gradient backdrop',
  'floating geometric shapes', 'floating three-dimensional shapes',
  'hypersaturated palette', 'lens flares all over the frame',
  '紫からティールへのグラデーション', '意味のない浮遊する3Dオブジェクト'
]

false_positive = keep.select { |term| rules.forbidden_match(term) }
missed = block.reject { |term| rules.forbidden_match(term) }

puts "（A）通すべき素材 #{keep.size} 件 : 誤検出 #{false_positive.size} 件（#{(false_positive.size * 100.0 / keep.size).round(1)}%）"
false_positive.each { |term| puts "  誤検出: #{term} <- #{rules.forbidden_match(term)}" }

puts "（B）止めるべき素材 #{block.size} 件 : 取りこぼし #{missed.size} 件（#{(missed.size * 100.0 / block.size).round(1)}%）"
missed.each { |term| puts "  取りこぼし: #{term}" }

# （C）短い語を登録した辞書での巻き込みです。
short = RuleDictionary.new(
  version: 'vmeasure.short',
  anti_ai_rules: {
    'forbidden_terms' => %w[teal purple glow 3d neon flare saturated particles floating art bokeh],
    'negative_prompt_terms' => ['deformed hands']
  }
)
short_rules = Generation::AntiAiRules.new(short)
caught = keep.select { |term| short_rules.forbidden_match(term) }
puts "（C）短い語 11 語での誤検出 : #{caught.size} 件（#{(caught.size * 100.0 / keep.size).round(1)}%）"
caught.each { |term| puts "  #{term} <- #{short_rules.forbidden_match(term)}" }
