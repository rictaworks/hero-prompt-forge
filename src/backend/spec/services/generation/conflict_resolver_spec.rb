# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::ConflictResolver do
  let(:anti_ai_rules) do
    { 'forbidden_terms' => ['purple to teal gradient'],
      'negative_prompt_terms' => ['deformed hands'] }
  end

  let(:dictionary) do
    RuleDictionary.create!(version: 'vspec.conflict', anti_ai_rules: anti_ai_rules)
  end

  let(:resolver) { described_class.new(dictionary: dictionary) }

  def input(**overrides)
    { industry: 'saas', style_family: 'photoreal', brand_tone: 'trust',
      copy_space_position: 'left', aspect_ratio: '16:9' }.merge(overrides)
  end

  def draft_for(**overrides)
    Generation::Draft.new(input: input(**overrides))
  end

  def resolved(**overrides)
    resolver.resolve(draft_for(**overrides))
  end

  def color_notes(draft)
    draft.notes.select { |note| note[:kind] == described_class::BRAND_COLOR_NOTE_KIND }
  end

  def color_note(draft)
    color_notes(draft).first
  end

  def tone_note(draft)
    draft.notes.find { |note| note[:kind] == described_class::TONE_NOTE_KIND }
  end

  # **矛盾入力でも出力を止めません**（requirements.md 4.2）。
  describe '出力を止めないこと' do
    it 'ブランドカラーが無くても統合できます' do
      expect { resolved }.not_to raise_error
    end

    it '2 色そろっていても統合できます' do
      expect { resolved(brand_colors: %w[#0E7C7B #F5A623]) }.not_to raise_error
    end

    it 'アンチAIルック規則に当たる色でも止まりません' do
      expect { resolved(brand_colors: ['#0E7C7B']) }.not_to raise_error
    end
  end

  # **ブランドカラーは支配色ではなくアクセントとして統合します。**
  describe 'ブランドカラーの統合' do
    it '色コードではなく色の名前で渡します' do
      terms = resolved(brand_colors: ['#0E7C7B']).main_terms

      expect(terms).to include(a_string_including('teal'))
      expect(terms).to all(satisfy { |term| term.exclude?('#0E7C7B') })
    end

    it 'アクセントとして統合します' do
      expect(resolved(brand_colors: ['#0E7C7B']).main_terms)
        .to include(a_string_including('accent'))
    end

    # **支配色にしません。** 業種の雰囲気も撮影の指示も塗りつぶされます。
    it '画面全体の支配色にしません' do
      terms = resolved(brand_colors: ['#0E7C7B']).main_terms

      expect(terms).to all(satisfy { |term| term.exclude?('dominant') && term.exclude?('overall color') })
    end

    it '1 色目と 2 色目の強さを分けます' do
      notes = color_notes(resolved(brand_colors: %w[#0E7C7B #F5A623]))

      expect(notes.pluck(:strength))
        .to eq([described_class::ACCENT, described_class::SECONDARY_ACCENT])
    end

    it '統合した内容をノートへ残します' do
      note = color_note(resolved(brand_colors: ['#0E7C7B']))

      expect(note[:color]).to eq('#0E7C7B')
      expect(note[:name]).to eq('teal')
    end

    it '指定が無ければ足しません' do
      expect(color_notes(resolved)).to be_empty
    end
  end

  # **アンチAIルック規則が落とす色は、捨てずに弱めます**（PR #135 の申し送り）。
  describe 'アンチAIルック規則に当たる色' do
    let(:anti_ai_rules) do
      { 'forbidden_terms' => ['teal'], 'negative_prompt_terms' => ['deformed hands'] }
    end

    it '落としません' do
      expect(resolved(brand_colors: ['#0E7C7B']).main_terms)
        .to include(a_string_including('teal'))
    end

    it '示唆の強さまで弱めます' do
      expect(resolved(brand_colors: ['#0E7C7B']).main_terms)
        .to include(a_string_including('barely visible hint'))
    end

    it '弱めた事実をノートへ残します' do
      note = color_note(resolved(brand_colors: ['#0E7C7B']))

      expect(note[:strength]).to eq(described_class::WEAKENED)
      expect(note[:matched]).to eq('teal')
    end

    it '当たらない色は弱めません' do
      note = color_note(resolved(brand_colors: ['#F5A623']))

      expect(note[:strength]).to eq(described_class::ACCENT)
      expect(note[:matched]).to be_nil
    end
  end

  # **トーン装飾は、いちばん弱い指定です。**
  describe 'トーン装飾' do
    Generation::InputChoices::BRAND_TONES.each do |tone|
      it "#{tone}：装飾を足します" do
        expect(resolved(brand_tone: tone).main_terms)
          .to include(a_string_including('overall impression'))
      end
    end

    it '示唆の言い方で足します' do
      expect(resolved.main_terms).to include(a_string_starting_with('an overall impression'))
    end

    it 'ノートへ残します' do
      expect(tone_note(resolved)[:tone]).to eq('trust')
    end
  end

  # **トーン装飾が余白と競合しないようにします。**
  # 余白の帯まで飾ると、文字が読めません。
  describe '余白との競合' do
    let(:reserved_draft) { Generation::CopySpace.new.apply(draft_for) }

    it '余白を確保していれば、余白を守る指定を足します' do
      expect(resolver.resolve(reserved_draft).main_terms)
        .to include(a_string_including('reserved copy area'))
    end

    it '守った事実をノートへ残します' do
      expect(tone_note(resolver.resolve(reserved_draft))[:restrained]).to be(true)
    end

    it '余白を確保していなければ、余白の指定を足しません' do
      expect(resolved.main_terms)
        .to all(satisfy { |term| term.exclude?('reserved copy area') })
    end

    # **コピースペースの指定を落としません。**
    it 'すでにある余白の指定を残します' do
      expect(resolver.resolve(reserved_draft).main_terms)
        .to include(a_string_including('copy space'))
    end

    it '余白の確保は保たれます' do
      expect(Generation::CopySpace.reserved?(resolver.resolve(reserved_draft))).to be(true)
    end
  end

  describe '下書きの引き継ぎ' do
    it 'すでにある素材を残します' do
      draft = draft_for.add(main_terms: ['35mm lens'])

      expect(resolver.resolve(draft).main_terms).to include('35mm lens')
    end

    it 'もとの下書きを変えません' do
      draft = draft_for
      resolver.resolve(draft)

      expect(draft.main_terms).to be_empty
    end
  end

  describe '素材の作り方' do
    it '打ち消しの言い回しを作りません' do
      terms = resolved(brand_colors: %w[#0E7C7B #F5A623]).main_terms
      negations = /(?<![a-z])(no|not|without|free of|avoid|never)(?![a-z])/

      expect(terms).to all(satisfy { |term| !term.match?(negations) })
    end

    it '日本語の素材を作りません' do
      expect(resolved(brand_colors: ['#0E7C7B']).main_terms)
        .to all(satisfy { |term| !term.match?(/[ぁ-んァ-ヶ一-龥]/) })
    end
  end

  describe '想定外の入力' do
    it '規則辞書が無ければ組み立てられません' do
      expect { described_class.new(dictionary: nil) }
        .to raise_error(described_class::MissingDictionaryError)
    end

    it 'トーンが無ければ失敗します' do
      bare = Generation::Draft.new(input: { industry: 'saas' })

      expect { resolver.resolve(bare) }.to raise_error(described_class::MissingToneError)
    end

    it '色コードの形が違えば失敗します' do
      expect { resolved(brand_colors: ['teal']) }
        .to raise_error(Generation::ColorName::InvalidColorError)
    end
  end

  # **統合の規則は人が編集するデータです。中身を信用しません。**
  describe '統合の規則の検め' do
    def with_definition(loaded)
      allow(YAML).to receive(:safe_load_file).and_return(loaded)
    end

    def sound_definition
      {
        'brand_color' => { 'accent' => 'a %<color>s accent',
                           'secondary_accent' => 'a small %<color>s detail',
                           'weakened' => 'a hint of %<color>s' },
        'tones' => Generation::InputChoices::BRAND_TONES.index_with { 'an impression' },
        'tone_restraint' => 'the reserved copy area left plain'
      }
    end

    it '規則が読めなければ失敗します' do
      with_definition('壊れています')

      expect { described_class.new(dictionary: dictionary) }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '弱めた形が無ければ失敗します' do
      broken = sound_definition
      broken['brand_color'].delete('weakened')
      with_definition(broken)

      expect { described_class.new(dictionary: dictionary) }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '色を差し込む場所が無ければ失敗します' do
      broken = sound_definition
      broken['brand_color']['accent'] = 'an accent color'
      with_definition(broken)

      expect { described_class.new(dictionary: dictionary) }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it 'トーンの装飾が足りなければ失敗します' do
      broken = sound_definition
      broken['tones'].delete('trust')
      with_definition(broken)

      expect { described_class.new(dictionary: dictionary) }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '余白を守る指定が無ければ失敗します' do
      broken = sound_definition
      broken.delete('tone_restraint')
      with_definition(broken)

      expect { described_class.new(dictionary: dictionary) }
        .to raise_error(described_class::InvalidDefinitionError)
    end
  end

  # **初期データでそのまま動くことを確かめます。**
  describe '初期データでの統合' do
    let(:anti_ai_rules) { InitialRuleDictionary.anti_ai_rules }

    it '仕様が定める 6 つのトーンすべてで統合できます' do
      Generation::InputChoices::BRAND_TONES.each do |tone|
        expect(resolved(brand_tone: tone).main_terms).not_to be_empty
      end
    end

    it '初期の規則辞書では、ブランドカラーを弱めません' do
      note = color_note(resolved(brand_colors: ['#0E7C7B']))

      expect(note[:strength]).to eq(described_class::ACCENT)
    end
  end
end
