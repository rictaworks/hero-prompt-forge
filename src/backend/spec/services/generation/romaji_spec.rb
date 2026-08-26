# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::Romaji do
  describe '.of' do
    describe 'ひらがな' do
      {
        'さくら' => 'Sakura',
        'こんにちは' => 'Konnichiha',
        'とうきょう' => 'Toukyou'
      }.each do |kana, romaji|
        it "「#{kana}」を「#{romaji}」にします" do
          expect(described_class.of(kana)).to eq(romaji)
        end
      end
    end

    describe 'カタカナ' do
      {
        'サクラ' => 'Sakura',
        'ラーメン' => 'Ramen',
        'ミライ' => 'Mirai'
      }.each do |kana, romaji|
        it "「#{kana}」を「#{romaji}」にします" do
          expect(described_class.of(kana)).to eq(romaji)
        end
      end
    end

    # **拗音を先に読みます。** 1 文字ずつ読むと「きゃ」が "kiya" になります。
    describe '拗音' do
      {
        'きゃ' => 'Kya',
        'しゅう' => 'Shuu',
        'ちょうし' => 'Choushi',
        'りょかん' => 'Ryokan'
      }.each do |kana, romaji|
        it "「#{kana}」を「#{romaji}」にします" do
          expect(described_class.of(kana)).to eq(romaji)
        end
      end
    end

    # **促音は、次の音の子音を重ねます。**
    # **`ch` の前は `t` を重ねます。** ヘボン式の決まりです。
    describe '促音' do
      {
        'がっこう' => 'Gakkou',
        'いっぷく' => 'Ippuku',
        'まっちゃ' => 'Matcha'
      }.each do |kana, romaji|
        it "「#{kana}」を「#{romaji}」にします" do
          expect(described_class.of(kana)).to eq(romaji)
        end
      end
    end

    # **「ん」の後ろに母音や y が続く場合は、区切りを入れます。**
    # 入れないと「しんいち」と「しにち」が同じ綴りになります。
    describe '撥音の区切り' do
      {
        'しんいち' => "Shin'ichi",
        'しにち' => 'Shinichi',
        'こんや' => "Kon'ya",
        'こにゃ' => 'Konya',
        'たんい' => "Tan'i"
      }.each do |kana, romaji|
        it "「#{kana}」を「#{romaji}」にします" do
          expect(described_class.of(kana)).to eq(romaji)
        end
      end
    end

    # **外来語の表記でも読めます。** カタカナの店名でよく使われます。
    describe '外来語の表記' do
      {
        'ヴィラ' => 'Vira',
        'カフェ' => 'Kafe',
        'フォレスト' => 'Foresuto',
        'チェーン' => 'Chen'
      }.each do |kana, romaji|
        it "「#{kana}」を「#{romaji}」にします" do
          expect(described_class.of(kana)).to eq(romaji)
        end
      end
    end

    describe '記号' do
      it '長音記号を落とします' do
        expect(described_class.of('コーヒー')).to eq('Kohi')
      end

      it '中黒を語の区切りにします' do
        expect(described_class.of('さくら・べーかりー')).to eq('Sakura Bekari')
      end
    end

    it '語の先頭を大文字にします' do
      expect(described_class.of('さくら')).to start_with('S')
    end

    # **翻訳しません。** 読みをそのまま写します。
    it '意味のある英単語へ置き換えません' do
      expect(described_class.of('さくら')).not_to eq('Cherry Blossom')
    end

    describe '想定外の入力' do
      it '漢字が混ざれば失敗します' do
        expect { described_class.of('櫻花堂') }.to raise_error(described_class::NotKanaError)
      end

      it '英字が混ざれば失敗します' do
        expect { described_class.of('さくらcafe') }.to raise_error(described_class::NotKanaError)
      end

      it '空なら失敗します' do
        expect { described_class.of(nil) }.to raise_error(described_class::NotKanaError)
      end

      # **促音で終わっても落ちません**（PR #149 のレビューより）。
      it '促音で終わっても落ちません' do
        expect(described_class.of('さくらっ')).to eq('Sakura')
      end
    end
  end

  describe '.kana?' do
    it 'ひらがなだけなら真です' do
      expect(described_class.kana?('さくら')).to be(true)
    end

    it 'カタカナだけなら真です' do
      expect(described_class.kana?('サクラ')).to be(true)
    end

    it '漢字が混ざれば偽です' do
      expect(described_class.kana?('さくら堂')).to be(false)
    end

    it '英字が混ざれば偽です' do
      expect(described_class.kana?('さくらcafe')).to be(false)
    end
  end

  # **対応表は人が編集するデータです。中身を信用しません。**
  describe '対応表の検め' do
    after { described_class.reset! }

    def with_definition(loaded)
      allow(YAML).to receive(:safe_load_file).and_return(loaded)
      described_class.reset!
    end

    it '定義が読めなければ失敗します' do
      with_definition('壊れています')

      expect { described_class.of('さくら') }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '拗音の表が無ければ失敗します' do
      with_definition({ 'singles' => { 'あ' => 'a' } })

      expect { described_class.of('さくら') }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '値が小文字の英字でなければ失敗します' do
      with_definition({ 'digraphs' => { 'きゃ' => 'kya' }, 'singles' => { 'あ' => 24 } })

      expect { described_class.of('さくら') }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    # **YAML は引用符の無い `no` を真偽値として読みます。**
    # 混ざると読みが黙って欠けます。
    it '真偽値が混ざれば失敗します' do
      with_definition({ 'digraphs' => { 'きゃ' => 'kya' }, 'singles' => { 'の' => false } })

      expect { described_class.of('さくら') }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '対応表に無いかななら失敗します' do
      with_definition({ 'digraphs' => { 'きゃ' => 'kya' }, 'singles' => { 'あ' => 'a' } })

      expect { described_class.of('さくら') }
        .to raise_error(described_class::InvalidDefinitionError)
    end
  end

  # **初期の対応表そのものを確かめます。**
  describe '初期の対応表' do
    it '五十音をすべて読めます' do
      expect { described_class.of('あいうえおかきくけこさしすせそたちつてとなにぬねの') }
        .not_to raise_error
    end

    it '濁音と半濁音を読めます' do
      expect { described_class.of('がぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽ') }
        .not_to raise_error
    end

    it '「の」が真偽値として読まれていません' do
      expect(described_class.of('のはら')).to eq('Nohara')
    end
  end
end
