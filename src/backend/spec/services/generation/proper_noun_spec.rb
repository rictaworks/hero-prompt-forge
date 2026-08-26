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
      '「さくら堂」という店の焼き菓子をお届けします。' => 'Sakuradou',
      '「櫻花堂」（おうかどう）の店構えを撮ります。' => 'Oukadou'
    }.each do |summary, romaji|
      it "「#{summary}」の名前をローマ字で写します" do
        expect(terms_in(summary)).to include(a_string_starting_with(romaji))
      end
    end

    it '英語へ訳しません' do
      expect(terms_in('「さくら」という名前のベーカリーです。'))
        .to all(satisfy { |term| term.exclude?('Cherry') })
    end
  end

  # **通してよい文章を壊さないことを、見つけることと同じくらい重視します。**
  #
  # 屋号の語尾だけを手がかりにすると、一般名詞を名前として拾います。
  # **かぎ括弧だけ、読みだけを手がかりにしても同じです。** 日本語では強調にも
  # かぎ括弧を使い、難しい一般名詞にも読みを添えます（PR #149 のレビューより）。
  describe '拾わないこと' do
    [
      '明るい部屋で撮影します。',
      '近所の本屋と食堂を背景にします。',
      '学校の校舎を遠景に入れます。',
      '古い山荘の外観です。',
      '落ち着いた雰囲気の歯科医院です。',
      '焙煎したての珈琲をお届けします。',
      '八百屋の店先を撮ります。',
      '旅館の大浴場を紹介します。',
      '公民館で開く教室です。',
      'お客様のご要望に合わせます。',
      '会社の雰囲気を伝えたいです。',
      '事務所のロゴを中央に置きます。',
      '製作所の職人が手作業で仕上げます。',
      '写真館のような柔らかい光にします。',
      '牧場の朝の風景です。',
      '工房の道具を並べます。',
      '商店街のにぎわいを表します。',
      '食堂のカウンターを撮ります。',
      '本屋の書棚を背景にします。',
      '部屋の隅に観葉植物を置きます。',
      '「安心」をお届けします。',
      '「ものづくり」の現場です。',
      '囲炉裏（いろり）のある宿です。',
      '定休日（ていきゅうび）は水曜です。',
      'やまだ（やまだ）さんが担当します。',
      '櫻花堂と月見堂（つきみどう）を紹介します。',
      '名前のとおり「明るい」雰囲気です。',
      '店名のような「親しみ」を大切にします。'
    ].each do |summary|
      it "「#{summary}」を名前として拾いません" do
        expect(found_in(summary)).to be_empty
      end
    end
  end

  # **手がかりが左側にある書き方も拾います**（PR #149 のレビューより）。
  describe '名前であることを先に述べる書き方' do
    {
      '屋号は「はな花」です。' => 'はな花',
      '店名は「さくら堂」です。' => 'さくら堂',
      'ブランド名は「ミライ」です。' => 'ミライ',
      '店名：「みどり」です。' => 'みどり',
      '社名が「あおぞら」に決まりました。' => 'あおぞら'
    }.each do |summary, name|
      it "「#{summary}」から「#{name}」を拾います" do
        expect(found_in(summary).map(&:original)).to include(name)
      end
    end

    # **助詞をすぐ後ろに求めます。**
    it '間に語が挟まる書き方は拾いません' do
      expect(found_in('名前のとおり「明るい」雰囲気です。')).to be_empty
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
  end

  # **読みが決まらない漢字を、推し量りません。**
  describe '読みが決まらない場合' do
    let(:summary) { '「東海林写真館」という店の外観です。' }

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
      expect(terms_in(summary)).to include(a_string_including('a proper name'))
    end
  end

  # **読みが添えられていれば、それを使います。**
  describe '読みが添えられている場合' do
    it '丸括弧の読みからローマ字を作ります' do
      expect(terms_in('「櫻花堂」（おうかどう）の店構えを撮ります。'))
        .to include(a_string_starting_with('Oukadou'))
    end

    it '半角の丸括弧でも読めます' do
      expect(terms_in('「櫻花堂」(おうかどう)の店構えを撮ります。'))
        .to include(a_string_starting_with('Oukadou'))
    end

    # **別の名前の読みを取り違えません**（PR #149 のレビューより）。
    it '別の名前へ付いた読みを、取り違えません' do
      found = found_in('「櫻花堂」という店と「月見堂」（つきみどう）を紹介します。')
      readable = found.select(&:readable?).map(&:romaji)

      expect(readable).to eq(['Tsukimidou'])
    end

    it '読みが添えられていない名前は、読めないままにします' do
      found = found_in('「櫻花堂」という店と「月見堂」（つきみどう）を紹介します。')

      expect(found.reject(&:readable?).map(&:original)).to eq(['櫻花堂'])
    end
  end

  # **屋号の語尾は読みが決まっています。**
  describe '屋号の語尾' do
    {
      '「さくら堂」' => 'Sakuradou',
      '「まるみ商店」' => 'Marumishouten',
      '「みどり牧場」' => 'Midoribokujou'
    }.each do |name, romaji|
      it "#{name}を「#{romaji}」にします" do
        expect(terms_in("#{name}という店の紹介です。"))
          .to include(a_string_starting_with(romaji))
      end
    end
  end

  describe '会社の名前の切り出し' do
    {
      '株式会社ミライ工房が運営します。' => 'ミライ工房',
      'ミライ工房株式会社です。' => 'ミライ工房',
      '株式会社さくらの家が運営します。' => 'さくらの家',
      '合同会社あおぞらと提携します。' => 'あおぞら'
    }.each do |summary, name|
      it "「#{summary}」から「#{name}」を取り出します" do
        expect(found_in(summary).map(&:original)).to include(name)
      end
    end

    it '助詞や語尾を名前に含めません' do
      expect(found_in('株式会社ミライ工房です。').map(&:original)).to eq(['ミライ工房'])
    end

    # **「の」より後ろまで拾いません**（issue #153）。
    #
    # **「の」が名前の一部か、文をつなぐ助詞かは、文字だけでは決まりません。**
    # 名前に使われる語（`name_forming_words`）が続く場合だけまたぎます。
    describe '「の」の扱い' do
      {
        '株式会社みらいの強みは提案力です。' => 'みらい',
        '株式会社みらいの事業は住宅です。' => 'みらい',
        '株式会社ひかりの実績をご覧ください。' => 'ひかり',
        '株式会社あおばの想いをお伝えします。' => 'あおば'
      }.each do |summary, name|
        it "「#{summary}」から「#{name}」だけを取り出します" do
          expect(found_in(summary).map(&:original)).to eq([name])
        end
      end

      {
        '株式会社さくらの家が運営します。' => 'さくらの家',
        '合同会社あおぞらの丘は分譲住宅を扱います。' => 'あおぞらの丘',
        '有限会社きらめきの工房をご紹介します。' => 'きらめきの工房',
        'さくらの家株式会社が運営します。' => 'さくらの家',
        # **「の」が語中にある名前を切り詰めません**（PR #157 のレビューより）。
        '株式会社みのりが運営します。' => 'みのり',
        '株式会社きのこは製菓会社です。' => 'きのこ',
        '株式会社たけのこをご紹介します。' => 'たけのこ',
        '株式会社あけぼのが運営します。' => 'あけぼの',
        '株式会社ものづくり研究所です。' => 'ものづくり研究所',
        '株式会社いのちの木が運営します。' => 'いのちの木',
        'このはな株式会社が運営します。' => 'このはな',
        'きのこ株式会社です。' => 'きのこ',
        # **「の」「は」は名前の先頭に現れます**（PR #157 の 2 回目のレビューより）。
        '株式会社のぞみが運営します。' => 'のぞみ',
        '株式会社はなまるをご紹介します。' => 'はなまる',
        # **助詞と同じ字で始まる名前・終わる名前**（PR #157 の 3 回目のレビューより）。
        '株式会社へいわが運営します。' => 'へいわ',
        '株式会社よりみちは喫茶店です。' => 'よりみち',
        '株式会社からだ工房が運営します。' => 'からだ工房',
        '株式会社やまとが運営します。' => 'やまと',
        '株式会社このはをご紹介します。' => 'このは',
        '株式会社いずもは酒造です。' => 'いずも'
      }.each do |summary, name|
        it "「#{summary}」から「#{name}」を切り詰めません" do
          expect(found_in(summary).map(&:original)).to include(name)
        end
      end

      # **重ねて落とします。**
      it '「の◯◯」が重なっても落とします' do
        expect(found_in('株式会社みらいの事業の強みをご覧ください。').map(&:original))
          .to eq(['みらい'])
      end

      # **落とすのは、会社の名前だけです**（PR #157 の 2 回目のレビューより）。
      # かぎ括弧で明示された名前は、利用者が名前として示したものです。
      it 'かぎ括弧で明示された名前は落としません' do
        expect(found_in('店名は「みらいの事業」です。').map(&:original)).to include('みらいの事業')
      end

      # **すべて落ちた場合は、名前がなかったものとして扱います。**
      it '会社そのものを指さない文からは拾いません' do
        expect(found_in('株式会社の設立をご支援します。')).to be_empty
      end

      # **名前が助詞で始まったり、助詞で終わったりする形は拾いません。**
      ['弊社は株式会社です。',
       '株式会社への変更をお手伝いします。',
       '合同会社から株式会社へ組織変更しました。'].each do |summary|
        it "「#{summary}」からは拾いません" do
          expect(found_in(summary)).to be_empty
        end
      end

      # **一覧に挙げた語だけを落とします。** 既定はそのまま残します。
      it '会社そのものを指さない語が続けば、そこを落とします' do
        expect(found_in('株式会社みらいの強みは提案力です。').map(&:original))
          .not_to include('みらいの強み')
      end
    end
  end

  describe '見つからない場合' do
    it '空（nil）なら空です' do
      expect(detector.call(service_summary: nil)).to be_empty
    end

    it '見つからなければ下書きを変えません' do
      draft = Generation::Draft.new(input: { service_summary: '落ち着いた歯科医院です。' })

      expect(detector.apply(draft).main_terms).to be_empty
    end
  end

  describe '下書きへの追加' do
    let(:draft) do
      Generation::Draft.new(
        input: { service_summary: '「さくら堂」という店の焼き菓子をお届けします。' }
      )
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
      found_in('「さくら堂」という店の焼き菓子をお届けします。')

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

    it '会社名のうしろに付く語の一覧が無ければ失敗します' do
      allow(YAML).to receive(:safe_load_file)
        .and_return({ 'rules' => [{ 'kind' => 'x', 'gloss' => 'a name', 'patterns' => ['(a)'] }] })

      expect { described_class.load_attribute_words }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    # **語そのものの形も検めます**（PR #157 のレビューより）。
    [[''], ['強み|特長'], ['強 み'], [1]].each do |words|
      it "うしろに付く語が「#{words.inspect}」なら失敗します" do
        allow(YAML).to receive(:safe_load_file)
          .and_return({ 'company_attribute_words' => words })

        expect { described_class.load_attribute_words }
          .to raise_error(described_class::InvalidDefinitionError)
      end
    end

    it '屋号の語尾の読みが読めなければ失敗します' do
      allow(YAML).to receive(:safe_load_file).and_return({ 'rules' => [] })

      expect { described_class.load_suffix_readings }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    # **外来語の表記でも落ちません**（PR #149 のレビューより）。
    it 'ヴを含む名前でも落ちません' do
      expect { found_in('「ヴィラさくら」という店の外観です。') }.not_to raise_error
    end

    it '促音で終わる名前でも落ちません' do
      expect { found_in('「さくらっ」という店の看板です。') }.not_to raise_error
    end

    it '小書きのかなを含む名前でも落ちません' do
      expect { found_in('「かゎいい」という店の看板です。') }.not_to raise_error
    end
  end
end
