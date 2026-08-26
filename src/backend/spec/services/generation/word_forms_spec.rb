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
      %w[lens glass grass gloss bokeh].each do |word|
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
