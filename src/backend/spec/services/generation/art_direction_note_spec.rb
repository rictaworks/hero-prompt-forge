# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::ArtDirectionNote do
  let(:anti_ai_rules) { InitialRuleDictionary.anti_ai_rules }

  let(:dictionary) do
    RuleDictionary.create!(version: 'vspec.note', anti_ai_rules: anti_ai_rules,
                           style_spec_rules: InitialRuleDictionary.style_spec_rules,
                           industry_defaults: InitialRuleDictionary.industry_defaults)
  end

  let(:note) { described_class.new }

  def input(**overrides)
    { industry: 'saas', style_family: 'photoreal', brand_tone: 'trust',
      copy_space_position: 'left', aspect_ratio: '16:9' }.merge(overrides)
  end

  # **実際の経路から下書きを作ります**（requirements.md 4.1）。
  def specified(**overrides)
    engine = Generation::RuleEngine.new(dictionary: dictionary)
    spec = Generation::StyleSpec.new(dictionary: dictionary)
                                .apply(engine.apply(engine.start(input(**overrides))))

    Generation::CopySpace.new.apply(spec)
  end

  def resolver
    Generation::ConflictResolver.new(dictionary: dictionary)
  end

  def resolved(**overrides)
    resolver.resolve(specified(**overrides))
  end

  def built(**overrides)
    note.for(resolved(**overrides))
  end

  def checkpoint(built_note, key)
    built_note.checkpoints.find { |item| item.key == key }
  end

  # AI っぽさを避ける規則に当たる色を指定した場合です。
  def weakened_built
    dictionary.update!(anti_ai_rules: { 'forbidden_terms' => ['teal'],
                                        'negative_prompt_terms' => ['deformed hands'] })
    built(brand_colors: ['#0E7C7B'])
  end

  # **仕様が定める 3 点を必ず含みます**（requirements.md 4.1 の 9）。
  describe '確かめること' do
    it 'コピースペースの可読性を含みます' do
      expect(checkpoint(built, :copy_space).text).to include('余白')
    end

    it '余白の位置を伝えます' do
      expect(checkpoint(built, :copy_space).text).to include('画面の左三分の一')
    end

    it 'ブランドカラーの再現度を含みます' do
      expect(checkpoint(built(brand_colors: ['#0E7C7B']), :brand_color).text)
        .to include('deep teal')
    end

    it 'クリシェ混入の有無を含みます' do
      expect(checkpoint(built, :cliche).text).to include('生成 AI にありがちな表現')
    end

    it '見出しを添えます' do
      expect(built.checkpoints).to all(satisfy { |item| item.heading.present? })
    end

    # **色の指定が無い場合も、確認の対象外であることを伝えます。**
    it 'ブランドカラーの指定が無ければ、対象外であることを伝えます' do
      expect(checkpoint(built, :brand_color).text).to include('対象外')
    end

    # **人物の指示が入っていない案は、その旨を伝えます。**
    it '人物の指示が入っていれば、崩れの確認を伝えます' do
      expect(checkpoint(built, :person_safety).text).to include('顔や指')
    end

    # **控えを読みます。「無いこと」から推し量りません**（PR #159 のレビューより）。
    it '業種の見込みで入れていなければ、その理由を伝えます' do
      expect(checkpoint(built(industry: 'ecommerce'), :person_safety).text)
        .to include('この業種では人物が写らない見込み')
    end

    it 'スタイルに定めが無ければ、その理由を伝えます' do
      expect(checkpoint(built(style_family: 'illustration'), :person_safety).text)
        .to include('定めがありません')
    end

    # **弱めた色と、そのまま入れた色を分けて確かめていただきます。**
    it '弱めた色には、弱めた前提で確かめていただきます' do
      expect(checkpoint(weakened_built, :brand_color).text).to include('ほのかに感じる程度')
    end

    it '弱めた色に「アクセントとして現れていますか」と尋ねません' do
      expect(checkpoint(weakened_built, :brand_color).text)
        .not_to include('アクセントとして現れていますか')
    end
  end

  # **矛盾解決で弱めた指定が明記されます**（issue #51 の受け入れ条件）。
  describe '調整したこと' do
    let(:anti_ai_rules) do
      { 'forbidden_terms' => ['teal'], 'negative_prompt_terms' => ['deformed hands'] }
    end

    it '弱めたブランドカラーを明記します' do
      expect(built(brand_colors: ['#0E7C7B']).adjustments)
        .to include(a_string_including('弱めて残しました'))
    end

    it '弱めた色の名前と色コードを添えます' do
      expect(built(brand_colors: ['#0E7C7B']).adjustments)
        .to include(a_string_including('deep teal'), a_string_including('#0E7C7B'))
    end

    it 'アクセントとして入れた色も明記します' do
      expect(built(brand_colors: ['#F5A623']).adjustments)
        .to include(a_string_including('アクセントとして入れました'))
    end

    it '2 色目の扱いを分けて明記します' do
      expect(built(brand_colors: %w[#F5A623 #7B0E7C]).adjustments)
        .to include(a_string_including('より弱く入れました'))
    end

    it '余白を飾らないようにしたことを明記します' do
      expect(built.adjustments).to include(a_string_including('控えめにしました'))
    end

    # **控えに無いことは書きません。**
    it '色の指定が無ければ、色の調整を書きません' do
      expect(built.adjustments).to all(satisfy { |line| line.exclude?('アクセント') })
    end
  end

  describe '想定外の入力' do
    it '下書きでなければ失敗します' do
      expect { note.for('下書きではありません') }
        .to raise_error(described_class::InvalidDraftError)
    end

    # **余白の指定が無い案は、使わないようにお伝えします。**
    it '余白の指定が無ければ、その旨を伝えます' do
      bare = Generation::Draft.new(input: input, main_terms: ['a calm office'])

      expect(checkpoint(note.for(bare), :copy_space).text).to include('使わないでください')
    end
  end

  describe '受け渡しの形' do
    it '確かめること・調整したこと・節の見出しを持ちます' do
      expect(built.to_h.keys).to contain_exactly(:checkpoints, :adjustments, :headings)
    end

    it '節の見出しを添えます' do
      expect(built.headings.values).to all(be_present)
    end

    it '確かめることは、印と見出しと本文を持ちます' do
      expect(checkpoint(built, :cliche).to_h.keys).to contain_exactly(:key, :heading, :text)
    end
  end

  # **バリエーションの展開（issue #50）を通した案でも、正しく出ます。**
  describe '3 案へ展開した案' do
    def variations(**overrides)
      Generation::VariationExpander.new(dictionary: dictionary)
                                   .expand(specified(**overrides))
                                   .map { |draft| resolver.resolve(draft) }
    end

    def notes(**overrides)
      variations(**overrides).map { |draft| note.for(draft) }
    end

    it '3 案すべてにノートが付きます' do
      expect(notes.size).to eq(3)
    end

    it '3 案すべてが、確かめることを持ちます' do
      expect(notes).to all(satisfy { |item| item.checkpoints.any? })
    end

    # **抽象背景の案は、人物を置かない案です。**
    it '抽象背景の案には、外した理由を伝えます' do
      expect(checkpoint(notes.third, :person_safety).text).to include('具体物を置かない')
    end

    it '外した役割を、日本語の呼び名で伝えます' do
      expect(notes.third.adjustments).to include(a_string_including('被写界深度'))
    end

    it '開発者向けの名前を出しません' do
      expect(notes.third.adjustments).to all(satisfy { |line| line.exclude?('depth_of_field') })
    end

    # **AI っぽさを避ける規則で落とした素材も伝えます。**
    #
    # **いまの工程では、規則の適用の時点で素材がまだありません**（issue #161）。
    # そのため、控えを直接持たせて確かめます。
    it '落とした素材を伝えます' do
      draft = variations.first.add(notes: [{ kind: Generation::RuleEngine::REMOVED_NOTE_KIND,
                                             term: 'purple to teal gradient',
                                             matched: 'purple to teal gradient' }])

      expect(note.for(draft).adjustments).to include(a_string_including('外しました'))
    end
  end

  # **役割の呼び名が無ければ、その場で失敗させます。**
  describe '役割の呼び名' do
    it '呼び名の無い役割は失敗します' do
      draft = resolved.add(notes: [{ kind: Generation::VariationExpander::DROPPED_NOTE_KIND,
                                     role: 'lens_mm', term: 'a 35mm lens' }])

      expect { note.for(draft) }.to raise_error(I18n::MissingTranslationData)
    end
  end
end
