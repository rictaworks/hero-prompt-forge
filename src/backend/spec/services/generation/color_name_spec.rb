# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::ColorName do
  describe '.of' do
    # **生成モデルへ色コードを渡しません。色の名前で渡します。**
    {
      '#FF0000' => 'red',
      '#FFA500' => 'orange',
      '#FFFF00' => 'yellow',
      '#00FF00' => 'green',
      '#0E7C7B' => 'teal',
      '#0000FF' => 'blue',
      '#7B0E7C' => 'purple',
      '#FF69B4' => 'pink',
      '#FFFFFF' => 'white',
      '#000000' => 'black',
      '#808080' => 'gray'
    }.each do |color, name|
      it "「#{color}」を「#{name}」にします" do
        expect(described_class.of(color)).to eq(name)
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
      expect(described_class.of('#0e7c7b')).to eq('teal')
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
    after { described_class.reset! }

    def with_definition(loaded)
      allow(YAML).to receive(:safe_load_file).and_return(loaded)
      described_class.reset!
    end

    def sound_definition
      {
        'achromatic_saturation' => 0.12, 'black_lightness' => 0.12,
        'white_lightness' => 0.92, 'achromatic_name' => 'gray',
        'hues' => [{ 'from' => 0, 'to' => 360, 'name' => 'red' }]
      }
    end

    it '定義が読めなければ失敗します' do
      with_definition('壊れています')

      expect { described_class.of('#FF0000') }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '鍵が足りなければ失敗します' do
      broken = sound_definition
      broken.delete('achromatic_name')
      with_definition(broken)

      expect { described_class.of('#FF0000') }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '色相の範囲に隙間があれば失敗します' do
      broken = sound_definition
      broken['hues'] = [{ 'from' => 0, 'to' => 180, 'name' => 'red' },
                        { 'from' => 200, 'to' => 360, 'name' => 'blue' }]
      with_definition(broken)

      expect { described_class.of('#FF0000') }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '色相の範囲が全周を覆っていなければ失敗します' do
      broken = sound_definition
      broken['hues'] = [{ 'from' => 0, 'to' => 180, 'name' => 'red' }]
      with_definition(broken)

      expect { described_class.of('#FF0000') }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '範囲の形が違えば失敗します' do
      broken = sound_definition
      broken['hues'] = [{ 'from' => 0, 'to' => 360, 'name' => '赤' }]
      with_definition(broken)

      expect { described_class.of('#FF0000') }
        .to raise_error(described_class::InvalidDefinitionError)
    end
  end

  # **初期の定義そのものを確かめます。**
  describe '初期の定義' do
    def sample_colors
      (0..255).step(17).flat_map do |value|
        [format('#%<v>02X%<v>02X00', v: value), format('#00%<v>02X%<v>02X', v: value),
         format('#%<v>02X00%<v>02X', v: value)]
      end
    end

    it 'どの色でも名前が決まります' do
      names = sample_colors.map { |color| described_class.of(color) }

      expect(names).to all(match(/\A[a-z]+\z/))
    end
  end
end
