# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::ProperNoun do
  let(:detector) { described_class.new }

  def found_in(text)
    detector.call(service_summary: text)
  end

  def terms_in(text)
    found_in(text).map(&:term)
  end

  # **翻訳しません。** 訳すと別の店の名前になります。
  describe '翻訳しないこと' do
    {
      '「さくら」という名前のベーカリーです。' => 'Sakura',
      '株式会社ミライ工房が運営します。' => 'Miraikoubou',
      'さくら堂の焼き菓子をお届けします。' => 'Sakuradou',
      'まるみ商店の店先です。' => 'Marumishouten'
    }.each do |summary, romaji|
      it "「#{summary}」の名前をローマ字で写します" do
        expect(terms_in(summary)).to include(a_string_starting_with(romaji))
      end

      it "「#{summary}」の名前を英語へ訳しません" do
        expect(terms_in(summary)).to all(satisfy { |term| term.exclude?('Cherry') })
      end
    end
  end

  # **意味説明を併記します。**
  describe '意味説明の併記' do
    it 'かぎ括弧の名前には、名前である旨を添えます' do
      expect(terms_in('「さくら」という名前のベーカリーです。'))
        .to include(a_string_including('a proper name'))
    end

    it '会社の名前には、会社である旨を添えます' do
      expect(terms_in('株式会社ミライ工房が運営します。'))
        .to include(a_string_including('a company name'))
    end

    it '屋号には、店である旨を添えます' do
      expect(terms_in('さくら堂の焼き菓子をお届けします。'))
        .to include(a_string_including('a shop name'))
    end
  end

  # **読みが決まらない漢字を、推し量りません。**
  # 「東海林」は「しょうじ」とも「とうかいりん」とも読みます。
  describe '読みが決まらない場合' do
    let(:summary) { '東海林写真館の外観です。' }

    it '元の表記のまま残します' do
      expect(terms_in(summary)).to include(a_string_starting_with('東海林写真館'))
    end

    it '読みを当てずっぽうで作りません' do
      expect(found_in(summary).first).not_to be_readable
    end

    it '元の表記のまま残したことを添えます' do
      expect(terms_in(summary)).to include(a_string_including('kept as written in Japanese'))
    end

    it '意味説明は併記します' do
      expect(terms_in(summary)).to include(a_string_including('a shop name'))
    end
  end

  # **読みが添えられていれば、それを使います。**
  describe '読みが添えられている場合' do
    it '丸括弧の読みからローマ字を作ります' do
      expect(terms_in('櫻花堂（おうかどう）の店構えを撮ります。'))
        .to include(a_string_starting_with('Oukadou'))
    end

    it '半角の丸括弧でも読めます' do
      expect(terms_in('櫻花堂(おうかどう)の店構えを撮ります。'))
        .to include(a_string_starting_with('Oukadou'))
    end
  end

  # **屋号の語尾は読みが決まっています。**
  describe '屋号の語尾' do
    {
      'さくら堂' => 'Sakuradou',
      'まるみ商店' => 'Marumishouten',
      'みどり牧場' => 'Midoribokujou'
    }.each do |name, romaji|
      it "「#{name}」を「#{romaji}」にします" do
        expect(terms_in("#{name}の紹介です。")).to include(a_string_starting_with(romaji))
      end
    end

    it '長い語尾から先に読みます' do
      expect(terms_in('みどり牧場の紹介です。')).to include(a_string_starting_with('Midoribokujou'))
    end
  end

  describe '見つからない場合' do
    it '固有名詞が無ければ空です' do
      expect(found_in('落ち着いた雰囲気の歯科医院です。')).to be_empty
    end

    it '空（nil）なら空です' do
      expect(detector.call(service_summary: nil)).to be_empty
    end

    it '見つからなければ下書きを変えません' do
      draft = Generation::Draft.new(input: { service_summary: '落ち着いた歯科医院です。' })

      expect(detector.apply(draft).main_terms).to be_empty
    end
  end

  describe '同じ名前が複数の手がかりに当たる場合' do
    it '1件にまとめます' do
      expect(found_in('「さくら堂」の焼き菓子です。').map(&:original).uniq.size)
        .to eq(found_in('「さくら堂」の焼き菓子です。').size)
    end
  end

  describe '下書きへの追加' do
    let(:draft) do
      Generation::Draft.new(input: { service_summary: 'さくら堂の焼き菓子をお届けします。' })
    end

    it '素材へ足します' do
      expect(detector.apply(draft).main_terms).to include(a_string_starting_with('Sakuradou'))
    end

    it 'ノートへ残します' do
      note = detector.apply(draft).notes.first

      expect(note[:kind]).to eq(described_class::NOTE_KIND)
      expect(note[:original]).to eq('さくら堂')
      expect(note[:readable]).to be(true)
    end

    it 'もとの下書きを変えません' do
      detector.apply(draft)

      expect(draft.main_terms).to be_empty
    end

    it 'すでにある素材を残します' do
      with_terms = draft.add(main_terms: ['35mm lens'])

      expect(detector.apply(with_terms).main_terms).to include('35mm lens')
    end
  end

  # **記録に名前そのものを残しません。**
  describe '記録に残す内容' do
    before { allow(Trace).to receive(:step).and_call_original }

    it '種別と件数だけを残します' do
      found_in('さくら堂の焼き菓子をお届けします。')

      expect(Trace).to have_received(:step) do |name, context|
        expect(name).to eq('generation.proper_noun_found')
        expect(context.keys).to contain_exactly(:kinds, :count, :unreadable)
      end
    end

    it '見つからなければ記録しません' do
      found_in('落ち着いた歯科医院です。')

      expect(Trace).not_to have_received(:step)
    end
  end

  describe '想定外の入力' do
    it '文字列でなければ失敗します' do
      expect { detector.call(service_summary: 123) }
        .to raise_error(described_class::InvalidInputError)
    end

    it '定義が読めなければ失敗します' do
      expect { described_class.load_rules(path: 'config/absent.yml') }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '意味説明が英文でなければ失敗します' do
      allow(YAML).to receive(:safe_load_file)
        .and_return({ 'rules' => [{ 'kind' => 'x', 'gloss' => '名前', 'patterns' => ['(a)'] }] })

      expect { described_class.load_rules }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '屋号の語尾の読みが読めなければ失敗します' do
      allow(YAML).to receive(:safe_load_file).and_return({ 'rules' => [] })

      expect { described_class.load_suffix_readings }
        .to raise_error(described_class::InvalidDefinitionError)
    end
  end
end
