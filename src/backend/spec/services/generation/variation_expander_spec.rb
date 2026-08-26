# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::VariationExpander do
  let(:dictionary) do
    RuleDictionary.create!(version: 'vspec.variation',
                           anti_ai_rules: InitialRuleDictionary.anti_ai_rules,
                           style_spec_rules: InitialRuleDictionary.style_spec_rules,
                           industry_defaults: InitialRuleDictionary.industry_defaults)
  end

  let(:expander) { described_class.new(dictionary: dictionary) }

  before { Generation::VariationRules.reset! }

  after { Generation::VariationRules.reset! }

  def input(**overrides)
    { industry: 'saas', style_family: 'photoreal', brand_tone: 'trust',
      copy_space_position: 'left', aspect_ratio: '16:9' }.merge(overrides)
  end

  # **実際の経路から下書きを作ります。** 展開は、規則の適用・仕様化・
  # 余白の確保のあとに走ります（requirements.md 4.1）。
  def specified(**overrides)
    engine = Generation::RuleEngine.new(dictionary: dictionary)
    applied = engine.apply(engine.start(input(**overrides)))
    spec = Generation::StyleSpec.new(dictionary: dictionary).apply(applied)

    Generation::CopySpace.new.apply(spec)
  end

  def variations(**overrides)
    expander.expand(specified(**overrides))
  end

  def variation_note(draft)
    draft.notes.find { |note| note[:kind] == described_class::NOTE_KIND }
  end

  def dropped_notes(draft)
    draft.notes.select { |note| note[:kind] == described_class::DROPPED_NOTE_KIND }
  end

  # **必ず 3 案です**（requirements.md 4.2）。
  describe '案の数' do
    it '3 案を返します' do
      expect(variations.size).to eq(3)
    end

    it '案の番号を 1 から順に振ります' do
      expect(variations.map { |draft| variation_note(draft)[:number] }).to eq([1, 2, 3])
    end

    it 'それぞれ別の下書きです' do
      expect(variations.uniq.size).to eq(3)
    end

    it 'もとの下書きを変えません' do
      draft = specified
      expander.expand(draft)

      expect(described_class.expanded?(draft)).to be(false)
    end
  end

  # **3 案の構図が互いに異なります。**
  describe '構図の違い' do
    it '3 通りの構図を使います' do
      compositions = variations.map { |draft| variation_note(draft)[:composition] }

      expect(compositions.uniq.size).to eq(3)
    end

    it '主役の置き方が案ごとに違います' do
      focuses = variations.map do |draft|
        draft.main_terms.grep(/subject rendered|surrounding space|abstract composition/)
      end

      expect(focuses.uniq.size).to eq(3)
    end

    it '被写体主導の案は、被写体を前に大きく置きます' do
      expect(variations.first.main_terms).to include(a_string_including('main subject rendered large'))
    end

    it '環境主導の案は、周囲の空間を主役にします' do
      expect(variations.second.main_terms).to include(a_string_including('surrounding space'))
    end

    # **余白の確保を打ち消しません**（PR #155 のレビューより）。
    it '環境主導の案が、余白の確保を打ち消しません' do
      expect(variations.second.main_terms)
        .to all(satisfy { |term| term.exclude?('filling the frame') })
    end

    it '抽象背景の案は、具体物を置きません' do
      expect(variations.third.main_terms).to include(a_string_including('abstract composition'))
    end

    # **同じレンズ・同じ構図のまま主役だけを入れ替えません。**
    it '一覧で選べる指示を、案ごとに選び直します' do
      lenses = variations.map { |draft| draft.main_terms.grep(/lens/) }

      expect(lenses.uniq.size).to eq(3)
    end

    it '一覧で選べない指示は、案ごとに変えません' do
      fields = variations.first(2).map { |draft| draft.main_terms.grep(/depth of field/) }

      expect(fields.uniq.size).to eq(1)
    end

    # **主役の置き方は、控えの印から引きます**（PR #155 のレビューより）。
    # 素材の並びに頼ると、同じ素材がすでにある場合に前提が崩れます。
    it '案の印を控えへ残します' do
      compositions = variations.map { |draft| variation_note(draft)[:composition] }

      expect(compositions).to eq(%w[subject_led environment_led abstract_background])
    end
  end

  # **人物を避ける構図も、案ごとに選び直します。**
  describe '人物を避ける構図' do
    def safety_terms(draft)
      draft.main_terms.grep(/seen from behind|hands cropped|distant figure/)
    end

    it '案ごとに別の構図を選びます' do
      kept = variations.first(2).map { |draft| safety_terms(draft) }

      expect(kept.uniq.size).to eq(2)
    end

    # **抽象背景の案には、置く人物がありません。**
    it '抽象背景の案からは外します' do
      expect(safety_terms(variations.third)).to be_empty
    end

    it '外した事実をノートへ残します' do
      note = dropped_notes(variations.third).find { |item| item[:role] == 'person_safety' }

      expect(note[:term]).to be_present
    end

    # **控えを実際の素材に合わせます**（PR #155 のレビューより）。
    it '外した案では、当てた記録を残しません' do
      applied = variations.third.notes
                          .select { |item| item[:kind] == Generation::StyleSpec::PERSON_SAFETY_NOTE_KIND }

      expect(applied).to be_empty
    end

    # **人物が写らない見込みの業種には、そもそも構図が入りません。**
    it '人物の構図が無ければ、外す記録も残しません' do
      dropped = dropped_notes(variations(industry: 'ecommerce').third)

      expect(dropped.pluck(:role)).not_to include('person_safety')
    end

    it '人物の構図が無くても 3 案そろいます' do
      expect(variations(industry: 'ecommerce').size).to eq(3)
    end
  end

  # **抽象背景の案からは、被写体があることを前提にした指示をすべて外します**
  # （PR #155 のレビューより）。
  describe '被写体を前提とする指示' do
    it '被写界深度を外します' do
      expect(variations.third.main_terms).to all(satisfy { |term| term.exclude?('depth of field') })
    end

    it '被写体の置き場所を外します' do
      expect(variations.third.main_terms)
        .to all(satisfy { |term| term.exclude?('the main subject placed') })
    end

    it '被写体の収まりを外します' do
      expect(variations.third.main_terms)
        .to all(satisfy { |term| term.exclude?('the subject contained') })
    end

    # **余白の確保は外しません。** 最上位の指定です。
    it '余白の確保は残します' do
      expect(Generation::CopySpace.reserved?(variations.third)).to be(true)
    end

    it '余白を静かに保つ指定も残します' do
      expect(variations.third.main_terms)
        .to include(a_string_including('low contrast surface'))
    end

    it '外した役割を控えへ残します' do
      roles = dropped_notes(variations.third).pluck(:role)

      expect(roles).to include('depth_of_field', 'subject', 'gaze')
    end

    # **他の案では外しません。**
    it '被写体主導の案では外しません' do
      expect(dropped_notes(variations.first)).to be_empty
    end
  end

  describe '下書きの引き継ぎ' do
    it 'すでにある素材を残します' do
      draft = specified.add(main_terms: ['a calm office'])

      expect(expander.expand(draft)).to all(satisfy { |item| item.main_terms.include?('a calm office') })
    end

    it 'すでにあるノートを残します' do
      expect(variations).to all(satisfy do |draft|
        draft.notes.any? { |note| note[:kind] == Generation::StyleSpec::SPECIFICATIONS_NOTE_KIND }
      end)
    end

    # **控えを、実際の素材に合わせます**（PR #155 のレビューより）。
    it '選び直した値を控えへ反映します' do
      variations.each do |draft|
        note = draft.notes.find { |item| item[:kind] == Generation::StyleSpec::SPECIFICATIONS_NOTE_KIND }

        expect(note[:specifications] - draft.main_terms).to be_empty
      end
    end

    it '規則辞書の版を引き継ぎます' do
      expect(variations).to all(satisfy { |draft| draft.dictionary_version == 'vspec.variation' })
    end
  end

  describe '素材の作り方' do
    it '日本語の素材を作りません' do
      expect(variations).to all(satisfy do |draft|
        draft.main_terms.none? { |term| term.match?(/[ぁ-んァ-ヶ一-龥]/) }
      end)
    end

    it '打ち消しの言い回しを作りません' do
      negations = /(?<![a-z])(no|not|without|free of|avoid|never)(?![a-z])/

      expect(variations).to all(satisfy do |draft|
        draft.main_terms.none? { |term| term.match?(negations) }
      end)
    end
  end

  describe '想定外の入力' do
    it '規則辞書が無ければ組み立てられません' do
      expect { described_class.new(dictionary: nil) }
        .to raise_error(described_class::MissingDictionaryError)
    end

    it 'スタイル仕様化を通っていなければ失敗します' do
      bare = Generation::Draft.new(input: input)

      expect { expander.expand(bare) }
        .to raise_error(described_class::MissingSpecificationsError)
    end

    it '二度展開できません' do
      expect { expander.expand(variations.first) }
        .to raise_error(described_class::AlreadyExpandedError)
    end

    # **別の版の下書きは展開しません**（PR #155 のレビューより）。
    # 控えの指示と、いま引ける指示が食い違い、素材が黙って落ちます。
    it '別の版の下書きなら失敗します' do
      other = specified.replace(dictionary_version: 'vspec.other')

      expect { expander.expand(other) }
        .to raise_error(described_class::VersionMismatchError)
    end
  end

  # **展開の規則は人が編集するデータです。中身を信用しません。**
  describe '展開の規則の検め' do
    def with_definition(loaded)
      allow(YAML).to receive(:safe_load_file).and_return(loaded)
      Generation::VariationRules.reset!
    end

    def sound_definition
      {
        'order' => %w[subject_led environment_led abstract_background],
        'compositions' => {
          'subject_led' => { 'focus' => 'the main subject in front', 'drops' => [] },
          'environment_led' => { 'focus' => 'the surrounding space', 'drops' => [] },
          'abstract_background' => { 'focus' => 'planes and light',
                                     'drops' => ['person_safety'] }
        },
        'copy_space_conflicts' => ['filling the frame']
      }
    end

    def expect_rejected(broken)
      dictionary # 規則辞書を先に用意します。YAML の差し替えより後だと読めません
      with_definition(broken)

      expect { described_class.new(dictionary: dictionary) }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '規則が読めなければ失敗します' do
      expect_rejected('壊れています')
    end

    it '案が 3 通りそろっていなければ失敗します' do
      broken = sound_definition
      broken['order'] = %w[subject_led environment_led]

      expect_rejected(broken)
    end

    it '同じ案が重なっていれば失敗します' do
      broken = sound_definition
      broken['order'] = %w[subject_led subject_led environment_led]

      expect_rejected(broken)
    end

    it '構図の定義が無ければ失敗します' do
      broken = sound_definition
      broken['compositions'].delete('abstract_background')

      expect_rejected(broken)
    end

    it '主役の置き方が英文でなければ失敗します' do
      broken = sound_definition
      broken['compositions']['subject_led']['focus'] = '被写体を前に置きます'

      expect_rejected(broken)
    end

    # **打ち消しは、かえってその要素を呼び込みます。**
    it '打ち消しの言い回しがあれば失敗します' do
      broken = sound_definition
      broken['compositions']['subject_led']['focus'] = 'no people in the frame'

      expect_rejected(broken)
    end

    it '外す素材の一覧が読めなければ失敗します' do
      broken = sound_definition
      broken['compositions']['subject_led']['drops'] = 'person_safety'

      expect_rejected(broken)
    end

    it '外す素材の一覧に重複があれば失敗します' do
      broken = sound_definition
      broken['compositions']['abstract_background']['drops'] = %w[person_safety person_safety]

      expect_rejected(broken)
    end

    # **余白の確保を打ち消す言い回しを止めます。**
    it '余白と衝突する言い回しがあれば失敗します' do
      broken = sound_definition
      broken['compositions']['environment_led']['focus'] = 'the space filling the frame'

      expect_rejected(broken)
    end

    it '衝突する言い回しの一覧が無ければ失敗します' do
      broken = sound_definition
      broken.delete('copy_space_conflicts')

      expect_rejected(broken)
    end

    # **役割の名前を、組み立ての時点で検めます**（PR #155 の 2 回目のレビューより）。
    # 書き間違えても黙って何もしないと、「外した」と控えに書きながら素材が残ります。
    it '定義されていない役割を書けば、組み立てで失敗します' do
      dictionary
      broken = sound_definition
      broken['compositions']['abstract_background']['drops'] = ['no_such_role']
      allow(YAML).to receive(:safe_load_file).and_return(broken)
      Generation::VariationRules.reset!

      expect { described_class.new(dictionary: dictionary) }
        .to raise_error(described_class::UnknownRoleError)
    end
  end

  # **初期データでそのまま動くことを確かめます。**
  describe '初期データでの展開' do
    it '定義されているすべてのスタイル系統で 3 案そろいます' do
      Generation::StyleRules.new(dictionary).style_families.each do |style_family|
        expect(variations(style_family: style_family).size).to eq(3)
      end
    end

    it 'すべての業種で 3 案そろいます' do
      Generation::InputChoices::INDUSTRIES.each do |industry|
        expect(variations(industry: industry).size).to eq(3)
      end
    end
  end
end
