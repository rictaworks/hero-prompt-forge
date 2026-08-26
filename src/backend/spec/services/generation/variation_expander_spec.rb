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

  def specified(**overrides)
    engine = Generation::RuleEngine.new(dictionary: dictionary)
    applied = engine.apply(engine.start(input(**overrides)))

    Generation::StyleSpec.new(dictionary: dictionary).apply(applied)
  end

  def variations(**overrides)
    expander.expand(specified(**overrides))
  end

  def variation_note(draft)
    draft.notes.find { |note| note[:kind] == described_class::NOTE_KIND }
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
      focuses = variations.map { |draft| draft.main_terms.last }

      expect(focuses.uniq.size).to eq(3)
    end

    it '被写体主導の案は、被写体を前に大きく置きます' do
      expect(variations.first.main_terms).to include(a_string_including('main subject rendered large'))
    end

    it '環境主導の案は、周囲の空間を主役にします' do
      expect(variations.second.main_terms).to include(a_string_including('surrounding space'))
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
      fields = variations.map { |draft| draft.main_terms.grep(/depth of field/) }

      expect(fields.uniq.size).to eq(1)
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
      note = variations.third.notes
                       .find { |item| item[:kind] == described_class::PERSON_SAFETY_DROPPED_NOTE_KIND }

      expect(note[:compositions]).to be_present
    end

    # **人物が写らない見込みの業種には、そもそも構図が入りません。**
    it '人物の構図が無ければ、外す記録も残しません' do
      notes = variations(industry: 'ecommerce').third.notes
      dropped = notes.select { |item| item[:kind] == described_class::PERSON_SAFETY_DROPPED_NOTE_KIND }

      expect(dropped).to be_empty
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
          'subject_led' => { 'focus' => 'the main subject in front', 'keeps_people' => true },
          'environment_led' => { 'focus' => 'the surrounding space', 'keeps_people' => true },
          'abstract_background' => { 'focus' => 'planes and light', 'keeps_people' => false }
        }
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

    it '人物の扱いが真偽でなければ失敗します' do
      broken = sound_definition
      broken['compositions']['subject_led']['keeps_people'] = 'はい'

      expect_rejected(broken)
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
