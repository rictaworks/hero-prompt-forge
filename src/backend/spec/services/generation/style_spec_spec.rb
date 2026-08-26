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

  # 人物の見込みは業種の既定値から引きます（issue #139）。
  let(:industry_defaults) do
    {
      'saas' => { 'tone' => 'trust', 'style_family' => 'photoreal', 'people' => 'expected' },
      'ecommerce' => { 'tone' => 'friendly', 'style_family' => 'photoreal',
                       'people' => 'unlikely' }
    }
  end

  let(:dictionary) do
    RuleDictionary.create!(version: 'vspec.style', style_spec_rules: style_spec_rules,
                           industry_defaults: industry_defaults)
  end

  let(:spec) { described_class.new(dictionary: dictionary) }

  def draft_for(style_family, industry: 'saas')
    Generation::Draft.new(input: { industry: industry, style_family: style_family })
  end

  # **ノートの並びに頼りません。** 印で探します。
  def safety_note(draft)
    draft.notes.find do |note|
      [described_class::PERSON_SAFETY_NOTE_KIND,
       described_class::PERSON_SAFETY_SKIPPED_NOTE_KIND].include?(note[:kind])
    end
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
                                           style_spec_rules: broken,
                                           industry_defaults: industry_defaults)
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
    it '人物が写る見込みの業種では、避ける構図を足します' do
      expect(applied('photoreal').main_terms).to include('back view of the subject')
    end

    # **同時に複数を指示しません。** 後ろ姿・手元だけ・遠景を並べると、
    # 生成モデルはどれを採るか決められません（requirements.md 4.1 の 5）。
    it '当てる構図は 1 つだけです' do
      expect(applied('photoreal').main_terms).not_to include('cropped hands only')
    end

    it '一覧の先頭を既定として使います' do
      note = safety_note(applied('photoreal'))

      expect(note[:compositions]).to eq(['back view of the subject'])
    end

    it '避けた事実をノートへ残します' do
      note = safety_note(applied('photoreal'))

      expect(note[:kind]).to eq(described_class::PERSON_SAFETY_NOTE_KIND)
    end

    # **人物が写らない見込みの業種へ、人物を呼び込みません**（issue #139）。
    describe '人物が写らない見込みの業種' do
      def without_people(style_family)
        spec.apply(draft_for(style_family, industry: 'ecommerce'))
      end

      it '避ける構図を足しません' do
        expect(without_people('photoreal').main_terms)
          .not_to include('back view of the subject', 'cropped hands only')
      end

      it '撮影の指示は、これまでどおり足します' do
        expect(without_people('photoreal').main_terms).to include('35mm lens')
      end

      it '当てなかった事実をノートへ残します' do
        note = safety_note(without_people('photoreal'))

        expect(note[:kind]).to eq(described_class::PERSON_SAFETY_SKIPPED_NOTE_KIND)
        expect(note[:industry]).to eq('ecommerce')
      end

      it '理由が「業種の見込み」であることが分かります' do
        note = safety_note(without_people('photoreal'))

        expect(note[:reason]).to eq(described_class::SKIPPED_BECAUSE_PEOPLE_UNLIKELY)
      end
    end

    # **理由を分けます**（PR #145 のレビューより）。
    # 業種が「写る見込み」でも、スタイル系統に定義が無ければ当てません。
    # そのとき業種を理由にしたノートを残すと、読み手を誤らせます。
    describe '避ける構図の定義が無いスタイル系統' do
      it '構図を足しません' do
        expect(applied('illustration').main_terms)
          .not_to include('back view of the subject')
      end

      it '理由が「スタイル系統に定義が無い」ことが分かります' do
        note = safety_note(applied('illustration'))

        expect(note[:kind]).to eq(described_class::PERSON_SAFETY_SKIPPED_NOTE_KIND)
        expect(note[:reason]).to eq(described_class::SKIPPED_BECAUSE_STYLE_HAS_NONE)
      end

      it '業種を理由にしません' do
        note = applied('illustration').notes.first

        expect(note).not_to have_key(:industry)
      end

      # **業種の見込みを引きません。** 規則辞書に見込みが無い場合でも、
      # 定義の無い系統では止まりません。影響の範囲を実写系に抑えます。
      it '規則辞書に見込みが無くても、定義の無い系統では止まりません' do
        broken = RuleDictionary.create!(
          version: 'vspec.people-none', style_spec_rules: style_spec_rules,
          industry_defaults: { 'saas' => { 'tone' => 'trust' } }
        )

        expect { described_class.new(dictionary: broken).apply(draft_for('illustration')) }
          .not_to raise_error
      end
    end

    it '業種の見込みが選べない値なら失敗します' do
      broken = RuleDictionary.create!(
        version: 'vspec.people-broken', style_spec_rules: style_spec_rules,
        industry_defaults: { 'saas' => { 'people' => 'maybe' } }
      )

      expect { described_class.new(dictionary: broken).apply(draft_for('photoreal')) }
        .to raise_error(described_class::InvalidPeopleError)
    end

    it '業種の見込みが無ければ失敗します' do
      broken = RuleDictionary.create!(
        version: 'vspec.people-missing', style_spec_rules: style_spec_rules,
        industry_defaults: { 'saas' => { 'tone' => 'trust' } }
      )

      expect { described_class.new(dictionary: broken).apply(draft_for('photoreal')) }
        .to raise_error(described_class::InvalidPeopleError)
    end

    it '下書きに業種が無ければ失敗します' do
      bare = Generation::Draft.new(input: { style_family: 'photoreal' })

      expect { spec.apply(bare) }.to raise_error(described_class::MissingIndustryError)
    end

    it '返した構図の一覧へ足しても、規則の中身は変わりません' do
      rules = Generation::StyleRules.new(dictionary)
      rules.person_safety_for('photoreal') << 'すり替えました'

      expect(rules.person_safety_for('photoreal').size).to eq(2)
    end

    # **撮影指示の欠落と同格に扱います（requirements.md 4.2）。**
    # 規則辞書の編集で消えた場合に、黙って効かなくなることを防ぎます。
    it '実写系で避ける構図の定義が消えていたら失敗します' do
      without_safety = style_spec_rules.deep_dup
      without_safety['photoreal'].delete('person_safety')
      broken = RuleDictionary.create!(version: 'vspec.no-safety',
                                      style_spec_rules: without_safety,
                                      industry_defaults: industry_defaults)

      expect { described_class.new(dictionary: broken).apply(draft_for('photoreal')) }
        .to raise_error(described_class::InvalidDictionaryError)
    end

    it '実写系で避ける構図が空の一覧なら失敗します' do
      empty_safety = style_spec_rules.deep_dup
      empty_safety['photoreal']['person_safety'] = []
      broken = RuleDictionary.create!(version: 'vspec.empty-safety',
                                      style_spec_rules: empty_safety,
                                      industry_defaults: industry_defaults)

      expect { described_class.new(dictionary: broken).apply(draft_for('photoreal')) }
        .to raise_error(described_class::InvalidDictionaryError)
    end
  end

  # 適用した版を追えるようにします（requirements.md 7.2）。
  describe '規則辞書の版' do
    it '適用した版を下書きへ残します' do
      expect(applied('photoreal').dictionary_version).to eq('vspec.style')
    end

    it '同じ版であれば重ねて当てられます' do
      once = spec.apply(draft_for('photoreal'))

      expect { spec.apply(once) }.not_to raise_error
    end

    it '別の版を重ねて当てようとすると失敗します' do
      other = Generation::Draft.new(
        input: { style_family: 'photoreal' }, dictionary_version: 'vspec.other'
      )

      expect { spec.apply(other) }.to raise_error(described_class::VersionMismatchError)
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
          version: 'vspec.seed',
          style_spec_rules: InitialRuleDictionary.style_spec_rules,
          industry_defaults: InitialRuleDictionary.industry_defaults
        )
      )
    end

    it '実写系で、そのまま読める撮影の指示が出ます' do
      terms = seed_spec.apply(draft_for('photoreal')).main_terms

      expect(terms).to include('a 35mm lens')
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

  # **プロジェクト単位で、人物の見込みを上書きできます**（issue #147）。
  #
  # 規則辞書は全利用者で共有される単一のマスタです。**1 社のために編集すると、
  # 全社の出力が変わります。**
  describe '人物の見込みの上書き' do
    # **ノートの並びに頼りません。** 印で探します。
    def safety_note(draft)
      draft.notes.find do |note|
        [described_class::PERSON_SAFETY_NOTE_KIND,
         described_class::PERSON_SAFETY_SKIPPED_NOTE_KIND].include?(note[:kind])
      end
    end

    def overridden(style_family, industry:, people:)
      spec.apply(Generation::Draft.new(input: { style_family: style_family,
                                                industry: industry, people: people }))
    end

    # EC でも、アパレル・コスメはモデル着用のヒーローが主流です。
    it '写らない見込みの業種でも、写る側へ寄せられます' do
      draft = overridden('photoreal', industry: 'ecommerce', people: 'expected')

      expect(draft.main_terms).to include('back view of the subject')
    end

    # 製造でも、製品だけを写したい場合があります。
    it '写る見込みの業種でも、写らない側へ寄せられます' do
      draft = overridden('photoreal', industry: 'saas', people: 'unlikely')

      expect(draft.main_terms).not_to include('back view of the subject')
    end

    it '上書きが無ければ、業種の既定値を使います' do
      expect(applied('photoreal').main_terms).to include('back view of the subject')
    end

    # **どこから引いたかを控えへ残します。**
    it '上書きしたことが控えから分かります' do
      draft = overridden('photoreal', industry: 'ecommerce', people: 'expected')

      expect(safety_note(draft)[:people_source])
        .to eq(Generation::PeopleExpectation::FROM_PROJECT)
    end

    it '業種の既定値を使ったことも控えから分かります' do
      expect(safety_note(applied('photoreal'))[:people_source])
        .to eq(Generation::PeopleExpectation::FROM_INDUSTRY)
    end

    # **選択肢の外の値は、その場で失敗させます。**
    ['maybe', '', 'Expected', 1].each do |value|
      it "上書きが「#{value.inspect}」なら失敗します" do
        expect { overridden('photoreal', industry: 'saas', people: value) }
          .to raise_error(Generation::PeopleExpectation::InvalidOverrideError)
      end
    end
  end
end
