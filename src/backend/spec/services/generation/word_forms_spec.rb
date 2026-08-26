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

  # **そろえた事実を記録へ残します**（issue #148）。
  # どの語がなぜ消えたかを追うとき、どの規則が働いたかが要ります。
  describe '記録に残す内容' do
    before { allow(Trace).to receive(:step).and_call_original }

    it 'そろえた場合は記録へ残します' do
      described_class.canonical('glowing particles')

      expect(Trace).to have_received(:step).with('generation.word_forms_normalized',
                                                 hash_including(plural: 1))
    end

    it 'つづりをそろえた件数を残します' do
      described_class.canonical('over-saturated colours')

      expect(Trace).to have_received(:step).with('generation.word_forms_normalized',
                                                 hash_including(spelling: 1))
    end

    it '記号を落とした件数を残します' do
      described_class.canonical('smart, clean layout')

      expect(Trace).to have_received(:step).with('generation.word_forms_normalized',
                                                 hash_including(marks: 1))
    end

    # **そろえるものが無ければ、記録を増やしません。**
    it 'そろえなかった場合は残しません' do
      described_class.canonical('a calm office')

      expect(Trace).not_to have_received(:step)
    end

    # **記録へ利用者の入力そのものを入れません。**
    it '記録に語そのものを入れません' do
      described_class.canonical('glowing particles')

      expect(Trace).to have_received(:step) do |name, context|
        expect(name).to eq('generation.word_forms_normalized')
        expect(context.keys).to contain_exactly(:marks, :plural, :spelling)
        expect(context.values).to all(be_a(Integer))
      end
    end
  end

  # **対応表の不備に、起動時に気づけるようにします**（issue #148）。
  describe '対応表の検め' do
    it '対応表が壊れていれば、読み込みで失敗します' do
      allow(YAML).to receive(:safe_load_file).and_return('壊れています')

      expect { Generation::WordFormsTable.load }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '起動時に読み込む仕掛けがあります' do
      initializer = Rails.root.join('config/initializers/generation_definitions.rb')

      expect(initializer.read).to include('Generation::WordForms')
    end
  end
end
