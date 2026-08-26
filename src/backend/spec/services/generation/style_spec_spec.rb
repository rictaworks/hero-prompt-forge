# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::StyleSpec do
  let(:style_spec_rules) do
    {
      'photoreal' => {
        'required' => %w[lens_mm key_light fill_light rim_light depth_of_field],
        'lens_mm' => ['35mm lens', '50mm lens'],
        'lighting' => {
          'key_light' => 'soft key light from a north-facing window',
          'fill_light' => 'bounced fill from a white wall',
          'rim_light' => 'subtle rim light separating the subject'
        },
        'depth_of_field' => 'shallow depth of field on the subject plane',
        'person_safety' => ['back view of the subject', 'cropped hands only']
      },
      'illustration' => {
        'required' => %w[line_quality shading palette],
        'line_quality' => 'clean tapered linework',
        'shading' => 'flat shading with limited gradients',
        'palette' => 'restrained palette of three to four colors'
      },
      'three_d' => {
        'required' => %w[material rendering lighting_style],
        'material' => 'physically based materials',
        'rendering' => 'path traced rendering',
        'lighting_style' => 'single dominant light source'
      },
      'abstract' => {
        'required' => %w[geometry motion palette],
        'geometry' => 'geometry derived from the brand mark',
        'motion' => 'implied motion along a single axis',
        'palette' => 'two brand colors plus one neutral'
      }
    }
  end

  let(:dictionary) do
    RuleDictionary.create!(version: 'vspec.style', style_spec_rules: style_spec_rules)
  end

  let(:spec) { described_class.new(dictionary: dictionary) }

  def draft_for(style_family)
    Generation::Draft.new(input: { industry: 'saas', style_family: style_family })
  end

  def applied(style_family)
    spec.apply(draft_for(style_family))
  end

  describe '実写系' do
    it 'レンズ焦点距離を明示します' do
      expect(applied('photoreal').main_terms).to include('35mm lens')
    end

    it 'キーライトを明示します' do
      expect(applied('photoreal').main_terms)
        .to include('soft key light from a north-facing window')
    end

    it 'フィルライトを明示します' do
      expect(applied('photoreal').main_terms).to include('bounced fill from a white wall')
    end

    it 'リムライトを明示します' do
      expect(applied('photoreal').main_terms)
        .to include('subtle rim light separating the subject')
    end

    it '被写界深度を明示します' do
      expect(applied('photoreal').main_terms)
        .to include('shallow depth of field on the subject plane')
    end

    it '選べる値が一覧なら、先頭を既定に使います' do
      expect(applied('photoreal').main_terms).to include('35mm lens')
      expect(applied('photoreal').main_terms).not_to include('50mm lens')
    end
  end

  describe '撮影指示を欠かないこと' do
    def spec_without(style_family, item)
      broken = style_spec_rules.deep_dup
      broken[style_family].delete(item)
      broken[style_family]['lighting']&.delete(item)
      described_class.new(
        dictionary: RuleDictionary.create!(version: "vspec.missing-#{item}",
                                           style_spec_rules: broken)
      )
    end

    %w[lens_mm key_light fill_light rim_light depth_of_field].each do |item|
      it "#{item} が規則辞書に無ければ失敗します" do
        expect { spec_without('photoreal', item).apply(draft_for('photoreal')) }
          .to raise_error(described_class::InvalidDictionaryError)
      end
    end

    it '項目が空文字なら失敗します' do
      broken = style_spec_rules.deep_dup
      broken['photoreal']['depth_of_field'] = ''
      empty = described_class.new(
        dictionary: RuleDictionary.create!(version: 'vspec.empty-item', style_spec_rules: broken)
      )

      expect { empty.apply(draft_for('photoreal')) }
        .to raise_error(described_class::InvalidDictionaryError)
    end

    it '選べる値の一覧が空なら失敗します' do
      broken = style_spec_rules.deep_dup
      broken['photoreal']['lens_mm'] = []
      empty = described_class.new(
        dictionary: RuleDictionary.create!(version: 'vspec.empty-list', style_spec_rules: broken)
      )

      expect { empty.apply(draft_for('photoreal')) }
        .to raise_error(described_class::InvalidDictionaryError)
    end
  end

  # **辞書の値は、そのままプロンプトへ入れられる英文でなければなりません。**
  # 記号や数値を黙って文字列へ直すと、生成モデルへ「back_view」「24」といった
  # 意味をなさない語がそのまま渡ります。
  describe 'プロンプトとして意味をなさない値' do
    def spec_with(style_family, item, value)
      broken = style_spec_rules.deep_dup
      broken[style_family][item] = value
      described_class.new(
        dictionary: RuleDictionary.create!(version: "vspec.bad-#{item}-#{value.hash.abs}",
                                           style_spec_rules: broken)
      )
    end

    it '数値だけの値は失敗させます' do
      expect { spec_with('photoreal', 'lens_mm', [24, 35]).apply(draft_for('photoreal')) }
        .to raise_error(described_class::InvalidDictionaryError)
    end

    it '真偽値は失敗させます' do
      expect { spec_with('photoreal', 'depth_of_field', true).apply(draft_for('photoreal')) }
        .to raise_error(described_class::InvalidDictionaryError)
    end

    it '連想配列は失敗させます' do
      expect { spec_with('photoreal', 'depth_of_field', { 'a' => 1 }).apply(draft_for('photoreal')) }
        .to raise_error(described_class::InvalidDictionaryError)
    end

    it '避ける構図に数値が混ざれば失敗させます' do
      expect { spec_with('photoreal', 'person_safety', [24]).apply(draft_for('photoreal')) }
        .to raise_error(described_class::InvalidDictionaryError)
    end

    it '避ける構図が空文字なら失敗させます' do
      expect { spec_with('photoreal', 'person_safety', ['']).apply(draft_for('photoreal')) }
        .to raise_error(described_class::InvalidDictionaryError)
    end
  end

  describe 'イラスト系' do
    it '線の質感を明示します' do
      expect(applied('illustration').main_terms).to include('clean tapered linework')
    end

    it '陰影の付け方を明示します' do
      expect(applied('illustration').main_terms).to include('flat shading with limited gradients')
    end

    it '配色を明示します' do
      expect(applied('illustration').main_terms)
        .to include('restrained palette of three to four colors')
    end

    it '撮影の指示は足しません' do
      expect(applied('illustration').main_terms).not_to include('35mm lens')
    end
  end

  describe '3D 系' do
    it 'マテリアルを明示します' do
      expect(applied('three_d').main_terms).to include('physically based materials')
    end

    it 'レンダリング様式を明示します' do
      expect(applied('three_d').main_terms).to include('path traced rendering')
    end

    it '照明を明示します' do
      expect(applied('three_d').main_terms).to include('single dominant light source')
    end
  end

  describe '抽象系' do
    it '形の由来を明示します' do
      expect(applied('abstract').main_terms).to include('geometry derived from the brand mark')
    end

    it '動きの示唆を明示します' do
      expect(applied('abstract').main_terms).to include('implied motion along a single axis')
    end
  end

  describe '人物の破綻を構図で避けること' do
    it '実写系では避ける構図を足します' do
      expect(applied('photoreal').main_terms)
        .to include('back view of the subject', 'cropped hands only')
    end

    it '避けた事実をノートへ残します' do
      note = applied('photoreal').notes.first

      expect(note[:kind]).to eq(described_class::PERSON_SAFETY_NOTE_KIND)
      expect(note[:compositions]).to eq(['back view of the subject', 'cropped hands only'])
    end

    it '避ける構図の定義が無いスタイルでは、ノートを増やしません' do
      expect(applied('illustration').notes).to be_empty
    end

    it '返した構図の一覧へ足しても、規則の中身は変わりません' do
      rules = Generation::StyleRules.new(dictionary)
      rules.person_safety_for('photoreal') << 'すり替えました'

      expect(rules.person_safety_for('photoreal').size).to eq(2)
    end
  end

  describe '素材の作り方' do
    it '1件1指示で足します。1件へ詰め込みません' do
      terms = applied('photoreal').main_terms

      expect(terms).to all(satisfy { |term| term.exclude?(' and ') })
    end

    it '打ち消しの言い回しを作りません' do
      terms = applied('photoreal').main_terms

      expect(terms).to all(satisfy { |term| !term.match?(/\Ano /) })
    end

    it '日本語の素材を作りません' do
      terms = applied('photoreal').main_terms

      expect(terms).to all(satisfy { |term| !term.match?(/[ぁ-んァ-ヶ一-龥]/) })
    end
  end

  describe '下書きの引き継ぎ' do
    it 'すでにある素材を残します' do
      draft = draft_for('photoreal').add(main_terms: ['a calm office'])

      expect(spec.apply(draft).main_terms).to include('a calm office')
    end

    it '入力を持ち越します' do
      expect(applied('photoreal').input[:industry]).to eq('saas')
    end

    it 'もとの下書きを変えません' do
      draft = draft_for('photoreal')
      spec.apply(draft)

      expect(draft.main_terms).to be_empty
    end
  end

  describe '想定外の入力' do
    it '規則辞書が無ければ組み立てられません' do
      expect { described_class.new(dictionary: nil) }
        .to raise_error(described_class::MissingDictionaryError)
    end

    it 'スタイル系統が下書きに無ければ失敗します' do
      bare = Generation::Draft.new(input: { industry: 'saas' })

      expect { spec.apply(bare) }.to raise_error(described_class::MissingStyleFamilyError)
    end

    it 'スタイル系統が空文字なら失敗します' do
      blank = Generation::Draft.new(input: { style_family: '  ' })

      expect { spec.apply(blank) }.to raise_error(described_class::MissingStyleFamilyError)
    end

    it '定義されていないスタイル系統なら失敗します' do
      unknown = Generation::Draft.new(input: { style_family: 'watercolor' })

      expect { spec.apply(unknown) }.to raise_error(described_class::UnknownStyleError)
    end

    it '規則辞書のスタイル仕様化規則が空なら失敗します' do
      empty = RuleDictionary.create!(version: 'vspec.no-style', style_spec_rules: {})

      expect { described_class.new(dictionary: empty) }
        .to raise_error(described_class::InvalidDictionaryError)
    end

    it '必ず出す項目の一覧が無ければ失敗します' do
      broken = RuleDictionary.create!(
        version: 'vspec.no-required',
        style_spec_rules: { 'photoreal' => { 'lens_mm' => ['35mm'] } }
      )

      expect { described_class.new(dictionary: broken) }
        .to raise_error(described_class::InvalidDictionaryError)
    end
  end

  describe '仕様が定める 4 系統' do
    it 'すべての系統に指示を出せます' do
      Generation::InputChoices::STYLE_FAMILIES.each do |style_family|
        expect(applied(style_family).main_terms).not_to be_empty
      end
    end
  end

  # **初期データでそのまま動くことを確かめます。**
  # テスト用の固定値だけで確かめると、初期データの構造が違っていても気づけません。
  describe '初期データでの適用' do
    let(:seed_spec) do
      described_class.new(
        dictionary: RuleDictionary.create!(
          version: 'vspec.seed', style_spec_rules: InitialRuleDictionary.style_spec_rules
        )
      )
    end

    it '実写系で、そのまま読める撮影の指示が出ます' do
      terms = seed_spec.apply(draft_for('photoreal')).main_terms

      expect(terms).to include('35mm lens')
    end

    it '実写系の指示に、記号や数値だけのものが混ざりません' do
      terms = seed_spec.apply(draft_for('photoreal')).main_terms

      expect(terms).to all(match(/[a-z]{3,}/))
    end

    it '避ける構図も、そのまま読める英文です' do
      terms = seed_spec.apply(draft_for('photoreal')).main_terms

      expect(terms).to include('the subject seen from behind')
    end

    it '4 系統すべてで、指示を取り出せます' do
      Generation::InputChoices::STYLE_FAMILIES.each do |style_family|
        expect(seed_spec.apply(draft_for(style_family)).main_terms).not_to be_empty
      end
    end
  end
end
