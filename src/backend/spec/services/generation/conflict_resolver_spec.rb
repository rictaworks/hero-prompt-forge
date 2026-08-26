# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::ConflictResolver do
  let(:anti_ai_rules) do
    { 'forbidden_terms' => ['purple to teal gradient'],
      'negative_prompt_terms' => ['deformed hands'] }
  end

  let(:dictionary) do
    RuleDictionary.create!(version: 'vspec.conflict', anti_ai_rules: anti_ai_rules,
                           style_spec_rules: InitialRuleDictionary.style_spec_rules,
                           industry_defaults: InitialRuleDictionary.industry_defaults)
  end

  let(:resolver) { described_class.new(dictionary: dictionary) }

  # **統合の規則は 1 度だけ読みます。** 例ごとに読み直させます。
  before { Generation::IntegrationRules.reset! }

  after { Generation::IntegrationRules.reset! }

  def input(**overrides)
    { industry: 'saas', style_family: 'photoreal', brand_tone: 'trust',
      copy_space_position: 'left', aspect_ratio: '16:9' }.merge(overrides)
  end

  # **コピースペースを確保した下書きを渡します。**
  # 矛盾解決は、余白の確保より後の段です（requirements.md 4.1）。
  def draft_for(**overrides)
    Generation::CopySpace.new.apply(Generation::Draft.new(input: input(**overrides)))
  end

  def bare_draft(**overrides)
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
      expect(note[:name]).to eq('deep teal')
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
    it '余白を守る指定を足します' do
      expect(resolved.main_terms).to include(a_string_including('reserved copy area'))
    end

    it '守った事実をノートへ残します' do
      expect(tone_note(resolved)[:restrained]).to be(true)
    end

    # **コピースペースの指定を落としません。**
    it 'すでにある余白の指定を残します' do
      expect(resolved.main_terms).to include(a_string_including('copy space'))
    end

    it '余白の確保は保たれます' do
      expect(Generation::CopySpace.reserved?(resolved)).to be(true)
    end

    # **黙って省きません。** 省くと、余白の帯が飾られた案がそのまま出ます。
    it '余白を確保していない下書きは統合できません' do
      expect { resolver.resolve(bare_draft) }
        .to raise_error(described_class::MissingCopySpaceError)
    end
  end

  describe '下書きの引き継ぎ' do
    it 'すでにある素材を残します' do
      draft = draft_for.add(main_terms: ['35mm lens'])

      expect(resolver.resolve(draft).main_terms).to include('35mm lens')
    end

    it 'もとの下書きを変えません' do
      draft = draft_for
      before = draft.main_terms
      resolver.resolve(draft)

      expect(draft.main_terms).to eq(before)
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
      without = Generation::CopySpace.new
                                     .apply(Generation::Draft.new(input: input.except(:brand_tone)))

      expect { resolver.resolve(without) }.to raise_error(described_class::MissingToneError)
    end

    it '色コードの形が違えば失敗します' do
      expect { resolved(brand_colors: ['teal']) }
        .to raise_error(Generation::ColorName::InvalidColorError)
    end
  end

  # **統合の規則は人が編集するデータです。中身を信用しません。**
  describe '統合の規則の検め' do
    def with_definition(loaded)
      dictionary # 規則辞書を先に用意します。YAML の差し替えより後だと読めません
      allow(YAML).to receive(:safe_load_file).and_return(loaded)
      Generation::IntegrationRules.reset!
    end

    def sound_definition
      {
        'brand_color' => { 'accent' => '%<color>s used as the accent',
                           'secondary_accent' => '%<color>s as a small detail',
                           'weakened' => '%<color>s as a hint' },
        'brand_color_restraint' => 'the brand accent placed away from the copy area',
        'style_palette_conflict' => { 'items' => ['palette'],
                                      'weakened' => 'a restrained palette' },
        'tones' => Generation::InputChoices::BRAND_TONES.index_with { 'an impression' },
        'tone_restraint' => 'the reserved copy area kept plain'
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

    it 'ブランドカラーを余白から離す指定が無ければ失敗します' do
      broken = sound_definition
      broken.delete('brand_color_restraint')
      with_definition(broken)

      expect { described_class.new(dictionary: dictionary) }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it 'スタイル系統との衝突の規則が無ければ失敗します' do
      broken = sound_definition
      broken.delete('style_palette_conflict')
      with_definition(broken)

      expect { described_class.new(dictionary: dictionary) }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    # **空白だけを弾いても足りません**（PR #151 のレビューより）。
    # 日本語はそのまま生成モデルへ渡り、打ち消しはその要素を呼び込みます。
    it '日本語の規則は失敗します' do
      broken = sound_definition
      broken['tones']['trust'] = '落ち着いた印象'
      with_definition(broken)

      expect { described_class.new(dictionary: dictionary) }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '打ち消しの言い回しは失敗します' do
      broken = sound_definition
      broken['brand_color']['accent'] = 'no %<color>s anywhere'
      with_definition(broken)

      expect { described_class.new(dictionary: dictionary) }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    # **有無だけを見ると、生成のたびに落ちます**（PR #151 の 2 回目のレビューより）。
    it '色を差し込めない書き方は失敗します' do
      broken = sound_definition
      broken['brand_color']['accent'] = '%<color>s with 100% coverage'
      with_definition(broken)

      expect { described_class.new(dictionary: dictionary) }
        .to raise_error(described_class::InvalidDefinitionError)
    end
  end

  # **英文として成立していることを確かめます**（PR #151 のレビューより）。
  describe '組み上がった英文' do
    # 色の名前は母音で始まるものと子音で始まるものが混ざります。
    # `a %<color>s` と書くと `a orange` になります。
    it '冠詞の誤りを作りません' do
      terms = resolved(brand_colors: %w[#F5A623 #D9C7A8]).main_terms

      expect(terms).to all(satisfy { |term| !term.match?(/\ba\s+[aeiou]/i) })
    end

    it '英語だけで組み立てます' do
      terms = resolved(brand_colors: %w[#0E7C7B #F5A623]).main_terms

      expect(terms).to all(match(/\A[\x20-\x7E]+\z/))
    end
  end

  # **優先順位の ① 余白 ＞ ② ブランドカラーを、出力に現します。**
  describe '余白とブランドカラーの優先順位' do
    it 'アクセントを余白から離します' do
      expect(resolved(brand_colors: ['#F5A623']).main_terms)
        .to include(a_string_including('brand accent placed away'))
    end

    it 'ブランドカラーの指定が無ければ足しません' do
      expect(resolved.main_terms)
        .to all(satisfy { |term| term.exclude?('brand accent placed away') })
    end
  end

  # **優先順位の ② ブランドカラー ＞ ③ スタイル系統を、出力に現します。**
  #
  # スタイル系統の配色指定は事実上の支配色の指定です。
  # 「アクセントとして統合する」という ② の扱いと食い違います。
  describe 'スタイル系統との優先順位' do
    def palette_notes(draft)
      draft.notes.select { |note| note[:kind] == described_class::STYLE_PALETTE_NOTE_KIND }
    end

    let(:palette_term) { 'two brand colors plus one neutral' }

    let(:styled) do
      draft_for(brand_colors: ['#F5A623'], style_family: 'abstract').add(main_terms: [palette_term])
    end

    it '配色の指定を弱めます' do
      expect(resolver.resolve(styled).main_terms)
        .to include('a restrained palette led by the brand accent')
    end

    it '弱める前の指定を残しません' do
      expect(resolver.resolve(styled).main_terms)
        .to all(satisfy { |term| term.exclude?('two brand colors') })
    end

    it '弱めた事実をノートへ残します' do
      note = palette_notes(resolver.resolve(styled)).first

      expect(note[:term]).to eq(palette_term)
      expect(note[:weakened]).to eq('a restrained palette led by the brand accent')
    end

    # **ブランドカラーの指定が無ければ、衝突しません。**
    it 'ブランドカラーの指定が無ければ、そのままにします' do
      bare = draft_for(style_family: 'abstract').add(main_terms: [palette_term])

      expect(resolver.resolve(bare).main_terms).to include(palette_term)
    end

    it '衝突しない素材はそのままにします' do
      draft = draft_for(brand_colors: ['#F5A623']).add(main_terms: ['35mm lens'])

      expect(resolver.resolve(draft).main_terms).to include('35mm lens')
    end

    # **語の一部が含まれるかどうかで当てません**（PR #151 の 2 回目のレビューより）。
    # 利用者由来の素材まで丸ごと置き換えると、この issue の目的に反します。
    ['a signboard showing the brand colors of the shop',
     'muted palette of natural wood tones',
     'wide palette of props on the counter'].each do |term|
      it "「#{term}」を置き換えません" do
        draft = draft_for(brand_colors: ['#F5A623'], style_family: 'abstract')
                .add(main_terms: [term])

        expect(resolver.resolve(draft).main_terms).to include(term)
      end
    end

    # **もともと重なっていた素材を、黙って 1 件へまとめません。**
    it '弱めない素材の数を変えません' do
      terms = ['35mm lens', 'a calm office', 'a calm office']
      draft = draft_for(brand_colors: ['#F5A623'], style_family: 'abstract')
              .add(main_terms: terms)
      kept = resolver.resolve(draft).main_terms.count { |term| terms.include?(term) }

      expect(kept).to eq(draft.main_terms.count { |term| terms.include?(term) })
    end

    # **配色指定を持たないスタイル系統では、何も弱めません。**
    it '配色指定を持たないスタイル系統では弱めません' do
      draft = draft_for(brand_colors: ['#F5A623'], style_family: 'photoreal')
              .add(main_terms: [palette_term])

      expect(palette_notes(resolver.resolve(draft))).to be_empty
    end
  end

  # **統合のあとにアンチAIルック規則を当てさせません**（PR #151 のレビューより）。
  #
  # 弱めて残したブランドカラーは、当たった語をそのまま含みます。
  # そのあとに規則を当てると、弱めた素材ごと落ち、ノートの説明と食い違います。
  describe '工程の順序' do
    let(:anti_ai_rules) do
      { 'forbidden_terms' => ['teal'], 'negative_prompt_terms' => ['deformed hands'] }
    end

    it '統合済みであることを見分けられます' do
      expect(described_class.integrated?(resolved)).to be(true)
    end

    it '統合前は統合済みと見なしません' do
      expect(described_class.integrated?(draft_for)).to be(false)
    end

    it '統合済みの下書きへ規則を当てられません' do
      integrated = resolved(brand_colors: ['#0E7C7B'])

      expect { Generation::RuleEngine.new(dictionary: dictionary).apply(integrated) }
        .to raise_error(Generation::RuleEngine::AlreadyIntegratedError)
    end

    # **関所は 1 か所では足りません**（PR #151 の 2 回目のレビューより）。
    it '統合済みの下書きへ仕様化を当てられません' do
      integrated = resolved(brand_colors: ['#0E7C7B'])

      expect { Generation::StyleSpec.new(dictionary: dictionary).apply(integrated) }
        .to raise_error(Generation::StyleSpec::AlreadyIntegratedError)
    end

    it '統合済みの下書きへコピースペースを規定できません' do
      integrated = resolved(brand_colors: ['#0E7C7B'])

      expect { Generation::CopySpace.new.apply(integrated) }
        .to raise_error(Generation::CopySpace::AlreadyIntegratedError)
    end

    it '二度統合できません' do
      expect { resolver.resolve(resolved) }
        .to raise_error(described_class::AlreadyIntegratedError)
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

    # **4.1 の 2 から 5 を、定められた順で通します。**
    it '規則の適用から統合までを通せます' do
      engine = Generation::RuleEngine.new(dictionary: dictionary)
      applied = engine.apply(engine.start(input(brand_colors: ['#0E7C7B'])))
      spec = Generation::StyleSpec.new(dictionary: dictionary).apply(applied)
      reserved = Generation::CopySpace.new.apply(spec)

      expect(resolver.resolve(reserved).main_terms).to include(a_string_including('deep teal'))
    end
  end
end
