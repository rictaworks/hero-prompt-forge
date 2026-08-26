# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::WordForms do
  describe '.canonical' do
    describe '複数形をそろえます' do
      {
        'glowing particles' => 'glowing particle',
        'glowing particle effects' => 'glowing particle effect',
        'floating objects' => 'floating object',
        'brand colors' => 'brand color',
        'boxes' => 'box',
        'stories' => 'story'
      }.each do |given, expected|
        it "「#{given}」を「#{expected}」にします" do
          expect(described_class.canonical(given)).to eq(expected)
        end
      end
    end

    describe '複数形でない語は触りません' do
      # 削ると別の語と同じ形になる語です。
      %w[lens glass grass gloss bokeh chaos cosmos sans news focus analysis canvas].each do |word|
        it "「#{word}」をそのままにします" do
          expect(described_class.canonical(word)).to eq(word)
        end
      end
    end

    describe '英国式のつづりを米国式へ寄せます' do
      {
        'oversaturated colours' => 'oversaturated color',
        'colour' => 'color',
        'grey backdrop' => 'gray backdrop',
        'watercolour illustration' => 'watercolor illustration'
      }.each do |given, expected|
        it "「#{given}」を「#{expected}」にします" do
          expect(described_class.canonical(given)).to eq(expected)
        end
      end
    end

    # **語尾の規則では見分けられない複数形です**（PR #144 のレビューより）。
    describe '対応表で単数形へ戻す複数形' do
      {
        'lenses' => 'lens',
        'glasses' => 'glass',
        'focuses' => 'focus',
        'analyses' => 'analysis'
      }.each do |given, expected|
        it "「#{given}」を「#{expected}」にします" do
          expect(described_class.canonical(given)).to eq(expected)
        end
      end

      it '対応表に無い語は、語尾の規則で寄せます' do
        expect(described_class.canonical('houses')).to eq('house')
      end
    end

    describe '語の前後の記号を落とします' do
      it '登録された語の記号を落とします' do
        expect(described_class.canonical('art,')).to eq('art')
      end

      it '素材の語の記号も落とします' do
        expect(described_class.canonical('smart, clean layout')).to eq('smart clean layout')
      end
    end

    describe '日本語は触りません' do
      it 'そのまま返します' do
        expect(described_class.canonical('紫からティールへのグラデーション'))
          .to eq('紫からティールへのグラデーション')
      end
    end

    it '語の並びを変えません' do
      expect(described_class.canonical('purple to teal gradient'))
        .to eq('purple to teal gradient')
    end

    it '空の語を渡しても落ちません' do
      expect(described_class.canonical('')).to eq('')
    end
  end

  describe '対応表の読み込み' do
    after { described_class.reset! }

    # **対応表は人が編集するデータです。中身を検めます。**
    describe '定義の不備' do
      def with_definition(loaded)
        allow(YAML).to receive(:safe_load_file).and_return(loaded)
        described_class.reset!
      end

      def sound_definition
        {
          'spelling_variants' => { 'colour' => 'color' },
          'singular_words' => ['lens'],
          'plural_forms' => { 'lenses' => 'lens' }
        }
      end

      it '定義が読めなければ失敗します' do
        with_definition('壊れています')

        expect { described_class.canonical('colour') }
          .to raise_error(described_class::InvalidDefinitionError)
      end

      it 'つづりの対応表が無ければ失敗します' do
        with_definition(sound_definition.merge('spelling_variants' => nil))

        expect { described_class.canonical('colour') }
          .to raise_error(described_class::InvalidDefinitionError)
      end

      it 'つづりの対応表が空なら失敗します' do
        with_definition(sound_definition.merge('spelling_variants' => {}))

        expect { described_class.canonical('colour') }
          .to raise_error(described_class::InvalidDefinitionError)
      end

      it '複数形の対応表が無ければ失敗します' do
        with_definition(sound_definition.merge('plural_forms' => nil))

        expect { described_class.canonical('colour') }
          .to raise_error(described_class::InvalidDefinitionError)
      end

      it '対応表の値が文字列でなければ失敗します' do
        with_definition(sound_definition.merge('spelling_variants' => { 'colour' => 24 }))

        expect { described_class.canonical('colour') }
          .to raise_error(described_class::InvalidDefinitionError)
      end

      it '同じ語へ寄せる行があれば失敗します' do
        with_definition(sound_definition.merge('spelling_variants' => { 'colour' => 'colour' }))

        expect { described_class.canonical('colour') }
          .to raise_error(described_class::InvalidDefinitionError)
      end

      it '英字以外の語が混ざっていれば失敗します' do
        with_definition(sound_definition.merge('spelling_variants' => { '色' => 'color' }))

        expect { described_class.canonical('colour') }
          .to raise_error(described_class::InvalidDefinitionError)
      end

      it '複数形でない語の一覧が一覧でなければ失敗します' do
        with_definition(sound_definition.merge('singular_words' => 'lens'))

        expect { described_class.canonical('colour') }
          .to raise_error(described_class::InvalidDefinitionError)
      end

      it '複数形でない語に英字以外が混ざっていれば失敗します' do
        with_definition(sound_definition.merge('singular_words' => ['レンズ']))

        expect { described_class.canonical('colour') }
          .to raise_error(described_class::InvalidDefinitionError)
      end
    end

    it '対応表を読めます' do
      expect(described_class.spelling_variants).to include('colour' => 'color')
    end

    it '対応表の中身が文字列です' do
      expect(described_class.spelling_variants.values).to all(be_a(String))
    end

    it '同じ語へ寄せる行を持ちません' do
      same = described_class.spelling_variants.select { |from, to| from == to }

      expect(same).to be_empty
    end
  end
end
