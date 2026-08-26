# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::ColorName do
  after { described_class.reset! }

  # 色相の全周を掃くために使います。組み立ては `spec/support/hsl_color.rb` にあります。
  def hex_from_hsl(hue, saturation, lightness)
    HslColor.new(hue: hue, saturation: saturation, lightness: lightness).to_hex
  end

  describe '.of' do
    # **生成モデルへ色コードを渡しません。色の名前で渡します。**
    {
      '#FF0000' => 'red',
      '#FFA500' => 'orange',
      '#FFFF00' => 'yellow',
      '#00FF00' => 'green',
      '#0E7C7B' => 'deep teal',
      '#0000FF' => 'blue',
      '#7B0E7C' => 'deep purple',
      '#FF69B4' => 'pink',
      '#FFFFFF' => 'white',
      '#000000' => 'black',
      '#808080' => 'gray'
    }.each do |color, name|
      it "「#{color}」を「#{name}」にします" do
        expect(described_class.of(color)).to eq(name)
      end
    end

    # **色相だけで名づけません**（PR #151 のレビューより）。
    # ベージュを `orange`、深緑を `green` と呼ぶと、生成モデルは鮮やかな色を返し、
    # 利用者のブランドカラーとかけ離れた指示になります。
    describe '明るさと鮮やかさ' do
      {
        '#D9C7A8' => 'pale orange',
        '#0B3D2E' => 'deep green',
        '#00704A' => 'deep green',
        '#001F5B' => 'deep blue',
        '#5F7F7A' => 'muted teal'
      }.each do |color, name|
        it "「#{color}」を「#{name}」にします" do
          expect(described_class.of(color)).to eq(name)
        end
      end

      # **修飾語は多くとも 1 つです。** 2 つ重ねると解釈が割れます。
      it '修飾語を 2 つ重ねません' do
        names = (0...360).step(3).map { |hue| described_class.of(hex_from_hsl(hue, 0.2, 0.2)) }

        expect(names).to all(match(/\A(?:deep|pale|muted)?[[:space:]]?[a-z]+\z/))
      end
    end

    # **色みが無い色を、色相で名づけません。**
    # 灰色に近い色へ「青」「緑」と名づけると、指示が実際の色から離れます。
    describe '色みが無い色' do
      {
        '#F5F5F5' => 'white',
        '#111111' => 'black',
        '#7A7E7A' => 'gray',
        '#8C8F94' => 'gray'
      }.each do |color, name|
        it "「#{color}」を「#{name}」にします" do
          expect(described_class.of(color)).to eq(name)
        end
      end
    end

    it '小文字の色コードも読めます' do
      expect(described_class.of('#0e7c7b')).to eq('deep teal')
    end

    describe '想定外の入力' do
      ['0E7C7B', '#0E7C7', 'teal', '', nil, 123].each do |value|
        it "「#{value.inspect}」なら失敗します" do
          expect { described_class.of(value) }
            .to raise_error(described_class::InvalidColorError)
        end
      end
    end
  end

  # **色相の範囲に隙間があると、その色だけ名前が決まらず、生成が止まります。**
  describe '定義の検め' do
    def with_definition(loaded)
      allow(YAML).to receive(:safe_load_file).and_return(loaded)
      described_class.reset!
    end

    def sound_definition
      {
        'achromatic_saturation' => 0.12, 'black_lightness' => 0.12,
        'white_lightness' => 0.92, 'achromatic_name' => 'gray',
        'modifiers' => { 'deep_lightness' => 0.30, 'deep_name' => 'deep',
                         'pale_lightness' => 0.72, 'pale_name' => 'pale',
                         'muted_saturation' => 0.30, 'muted_name' => 'muted' },
        'hues' => [{ 'from' => 0, 'to' => 360, 'name' => 'red' }]
      }
    end

    def expect_rejected(broken)
      with_definition(broken)

      expect { described_class.of('#FF0000') }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '定義が読めなければ失敗します' do
      expect_rejected('壊れています')
    end

    it '鍵が足りなければ失敗します' do
      broken = sound_definition
      broken.delete('achromatic_name')

      expect_rejected(broken)
    end

    it '色相の範囲に隙間があれば失敗します' do
      broken = sound_definition
      broken['hues'] = [{ 'from' => 0, 'to' => 180, 'name' => 'red' },
                        { 'from' => 200, 'to' => 360, 'name' => 'blue' }]

      expect_rejected(broken)
    end

    it '色相の範囲が全周を覆っていなければ失敗します' do
      broken = sound_definition
      broken['hues'] = [{ 'from' => 0, 'to' => 180, 'name' => 'red' }]

      expect_rejected(broken)
    end

    it '範囲の形が違えば失敗します' do
      broken = sound_definition
      broken['hues'] = [{ 'from' => 0, 'to' => 360, 'name' => '赤' }]

      expect_rejected(broken)
    end

    # **鍵の有無だけでは足りません**（PR #151 のレビューより）。
    # 値が壊れていると、すべての色が `gray` や `black` になります。
    describe 'しきい値の中身' do
      %w[achromatic_saturation black_lightness white_lightness].each do |key|
        it "#{key} が数値でなければ失敗します" do
          broken = sound_definition
          broken[key] = 'あかるさ'

          expect_rejected(broken)
        end

        it "#{key} が 0.0 から 1.0 の外なら失敗します" do
          broken = sound_definition
          broken[key] = 1.5

          expect_rejected(broken)
        end
      end

      it '黒と白のしきい値が逆なら失敗します' do
        broken = sound_definition
        broken['black_lightness'] = 0.9
        broken['white_lightness'] = 0.1

        expect_rejected(broken)
      end
    end

    describe '色みが無い色の名前' do
      ['', nil, '灰色', 'Gray', 'gray green'].each do |value|
        it "「#{value.inspect}」なら失敗します" do
          broken = sound_definition
          broken['achromatic_name'] = value

          expect_rejected(broken)
        end
      end
    end

    describe '修飾語の定義' do
      it '修飾語が無ければ失敗します' do
        broken = sound_definition
        broken.delete('modifiers')

        expect_rejected(broken)
      end

      %w[deep_lightness pale_lightness muted_saturation].each do |key|
        it "#{key} が数値でなければ失敗します" do
          broken = sound_definition
          broken['modifiers'][key] = 'ふかい'

          expect_rejected(broken)
        end
      end

      %w[deep_name pale_name muted_name].each do |key|
        it "#{key} が英単語でなければ失敗します" do
          broken = sound_definition
          broken['modifiers'][key] = '深い'

          expect_rejected(broken)
        end
      end

      it '明度のしきい値が逆なら失敗します' do
        broken = sound_definition
        broken['modifiers']['deep_lightness'] = 0.8
        broken['modifiers']['pale_lightness'] = 0.2

        expect_rejected(broken)
      end
    end
  end

  # **初期の定義そのものを確かめます。**
  describe '初期の定義' do
    # **色相の全周を掃きます。** 一部の色相だけでは、隙間を見つけられません。
    it 'どの色でも名前が決まります' do
      names = (0...360).flat_map do |hue|
        [0.15, 0.5, 0.85].flat_map do |lightness|
          [0.2, 0.6, 1.0].map { |saturation| described_class.of(hex_from_hsl(hue, saturation, lightness)) }
        end
      end

      expect(names).to all(match(/\A(?:(?:deep|pale|muted) )?[a-z]+\z/))
    end

    # **緑と青緑の境目を固定します。** requirements.md 4.2 は「紫からティールへの
    # グラデーション」をクリシェ配色の代表として名指しします。緑寄りの色まで
    # `teal` と呼ぶと、こちらからクリシェの語を呼び込みます（PR #151 のレビューより）。
    describe '色相の境目' do
      {
        169 => 'green',
        171 => 'teal',
        194 => 'teal',
        196 => 'blue'
      }.each do |hue, name|
        it "色相 #{hue} 度を「#{name}」にします" do
          expect(described_class.of(hex_from_hsl(hue, 0.8, 0.5))).to eq(name)
        end
      end
    end

    # **`teal` の占める割合を抑えます。**
    it '色相の全周のうち teal が占める割合を 1 割未満に保ちます' do
      names = (0...360).map { |hue| described_class.of(hex_from_hsl(hue, 0.8, 0.5)) }

      expect(names.count('teal').fdiv(names.size)).to be < 0.10
    end
  end
end
