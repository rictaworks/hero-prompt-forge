# frozen_string_literal: true

# アンチAIルック規則の検出範囲を、両方向で測ります（issue #136）。
#
# **片方だけを追うと、検出側が痩せても気づけません。**
# 素材の一覧は、レビューで積み上げたものです。減らさずに足してください。
class AntiAiCoverage
  # 通してよい素材です。撮影の指示・照明・被写界深度・ブランドカラーを含みます。
  def keep
    photography + business_scenes + confusing
  end

  def photography
    ['35mm lens', '24mm wide angle lens', '50mm lens', '85mm portrait lens',
     'soft key light from a north-facing window', 'bounced fill from a white wall',
     'subtle rim light separating the subject', 'shallow depth of field on the subject plane',
     'clean tapered linework', 'flat shading with limited gradients',
     'restrained palette of three to four colors', 'physically based materials',
     'path traced rendering, neutral tone mapping',
     'single dominant light source with soft shadows',
     'geometry derived from the brand mark', 'implied motion along a single axis',
     'two brand colors plus one neutral', 'the subject seen from behind',
     'hands cropped out of the frame', 'a distant figure within the scene']
  end

  def business_scenes
    ['a calm dental clinic waiting room', 'a warm bakery counter at dawn',
     'an architect reviewing blueprints', 'a tidy law office bookshelf',
     'a nurse walking a bright corridor', 'a classroom with afternoon light',
     'a workshop bench with hand tools', 'a rooftop terrace at golden hour',
     'a minimal product still life', 'a quiet library reading room']
  end

  # **意図して紛らわしくした素材です。** 短い語を登録したときの巻き込みを測ります。
  def confusing
    ['stealth startup founders', 'artisan coffee roastery',
     'a heartfelt customer testimonial', 'a factory line with metal parts',
     'glowing laptop screen', 'soft lens flare through a window',
     'teal accent on a brand sign', 'purple brand accent on a coffee cup',
     'saturated red brand accent', '3d printed prototype on a workbench']
  end

  # 止めるべき素材です。表記のゆれ・語順違い・言い換え・日本語を含みます。
  def block
    ['purple to teal gradient', 'purple to teal gradient background',
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
     '紫からティールへのグラデーション', '意味のない浮遊する3Dオブジェクト']
  end

  # 短い語だけを登録した規則辞書です。巻き込みの度合いを測ります。
  def short_terms
    %w[teal purple glow 3d neon flare saturated particles floating art bokeh]
  end

  def report
    report_initial
    report_short
  end

  private

  def initial_rules
    Generation::AntiAiRules.new(
      RuleDictionary.new(version: 'vmeasure', anti_ai_rules: InitialRuleDictionary.anti_ai_rules)
    )
  end

  def short_rules
    Generation::AntiAiRules.new(
      RuleDictionary.new(
        version: 'vmeasure.short',
        anti_ai_rules: { 'forbidden_terms' => short_terms,
                         'negative_prompt_terms' => ['deformed hands'] }
      )
    )
  end

  def report_initial
    rules = initial_rules
    false_positive = keep.select { |term| rules.forbidden_match(term) }
    missed = block.reject { |term| rules.forbidden_match(term) }

    puts "（A）通すべき素材 #{keep.size} 件 : 誤検出 #{percentage(false_positive.size, keep.size)}"
    false_positive.each { |term| puts "  誤検出: #{term} <- #{rules.forbidden_match(term)}" }
    puts "（B）止めるべき素材 #{block.size} 件 : 取りこぼし #{percentage(missed.size, block.size)}"
    missed.each { |term| puts "  取りこぼし: #{term}" }
  end

  def report_short
    rules = short_rules
    caught = keep.select { |term| rules.forbidden_match(term) }

    puts "（C）短い語 #{short_terms.size} 語での誤検出 : #{percentage(caught.size, keep.size)}"
    caught.each { |term| puts "  #{term} <- #{rules.forbidden_match(term)}" }
  end

  def percentage(count, total)
    "#{count} 件（#{(count * 100.0 / total).round(1)}%）"
  end
end

AntiAiCoverage.new.report
