# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::Draft do
  let(:input) { { industry: 'saas', style_family: 'photoreal', target_model: 'midjourney' } }

  def draft(**overrides)
    described_class.new(input: input, **overrides)
  end

  describe '組み立て' do
    it '入力を持ちます' do
      expect(draft.input).to eq(input)
    end

    it '素材は空から始まります' do
      expect(draft.main_terms).to be_empty
      expect(draft.negative_terms).to be_empty
      expect(draft.notes).to be_empty
    end

    it '規則辞書の版は空から始まります' do
      expect(draft.dictionary_version).to be_nil
    end
  end

  describe '書き換えられないこと' do
    it '下書きそのものが凍っています' do
      expect(draft).to be_frozen
    end

    it '素材の配列が凍っています' do
      expect(draft.main_terms).to be_frozen
      expect(draft.negative_terms).to be_frozen
      expect(draft.notes).to be_frozen
    end

    it '素材へ直接足そうとすると失敗します' do
      expect { draft.main_terms << 'a calm office' }.to raise_error(FrozenError)
    end

    # **器だけを凍らせても、中身は書き換えられます。**
    # 「書き換えません」という約束を守るには、中身まで凍らせる必要があります。
    it '入力の中身を書き換えようとすると失敗します' do
      expect { draft.input[:industry] = 'changed' }.to raise_error(FrozenError)
    end

    it 'ノートの中身を書き換えようとすると失敗します' do
      with_note = draft(notes: [{ kind: :anti_ai_removed, term: 'purple' }])

      expect { with_note.notes.first[:term] = 'changed' }.to raise_error(FrozenError)
    end

    it '入れ子になった入力の中身も書き換えられません' do
      nested = described_class.new(input: { brand: { colors: ['#111111'] } })

      expect { nested.input[:brand][:colors] << '#222222' }.to raise_error(FrozenError)
    end

    it '素材の中の文字列も書き換えられません' do
      with_terms = draft(main_terms: [+'a calm office'])

      expect { with_terms.main_terms.first << ' extra' }.to raise_error(FrozenError)
    end
  end

  describe '#add' do
    it '新しい下書きを返します' do
      original = draft

      expect(original.add(main_terms: ['a calm office'])).not_to equal(original)
    end

    it 'もとの下書きを変えません' do
      original = draft
      original.add(main_terms: ['a calm office'])

      expect(original.main_terms).to be_empty
    end

    it 'メインプロンプトの素材を足します' do
      expect(draft.add(main_terms: ['a calm office']).main_terms).to eq(['a calm office'])
    end

    it 'ネガティブプロンプトの素材を足します' do
      expect(draft.add(negative_terms: ['oversaturation']).negative_terms)
        .to eq(['oversaturation'])
    end

    it 'ノートを足します' do
      expect(draft.add(notes: [{ kind: :note }]).notes).to eq([{ kind: :note }])
    end

    it '同じ語を重ねません' do
      expect(draft.add(main_terms: ['a']).add(main_terms: %w[a b]).main_terms).to eq(%w[a b])
    end

    it 'ノートは重ねます。同じ観点が二度必要な場合があるためです' do
      note = { kind: :note }

      expect(draft.add(notes: [note]).add(notes: [note]).notes.size).to eq(2)
    end

    it '規則辞書の版を記録します' do
      expect(draft.add(dictionary_version: 'v1').dictionary_version).to eq('v1')
    end

    it '版を渡さなければ、もとの版を保ちます' do
      expect(draft.add(dictionary_version: 'v1').add(main_terms: ['a']).dictionary_version)
        .to eq('v1')
    end

    it '入力を持ち越します' do
      expect(draft.add(main_terms: ['a']).input).to eq(input)
    end
  end

  describe '#replace' do
    it '指定した部分だけを差し替えます' do
      original = draft.add(main_terms: %w[a b], negative_terms: ['x'])

      replaced = original.replace(main_terms: ['a'])

      expect(replaced.main_terms).to eq(['a'])
      expect(replaced.negative_terms).to eq(['x'])
    end

    it 'もとの下書きを変えません' do
      original = draft.add(main_terms: %w[a b])
      original.replace(main_terms: ['a'])

      expect(original.main_terms).to eq(%w[a b])
    end

    it '何も渡さなければ同じ内容を返します' do
      original = draft.add(main_terms: ['a'])

      expect(original.replace).to eq(original)
    end
  end

  describe '#==' do
    it '中身が同じなら等しいと見なします' do
      one = draft.add(main_terms: ['a'])
      other = draft.add(main_terms: ['a'])

      expect(one).to eq(other)
    end

    it '中身が違えば等しくありません' do
      expect(draft.add(main_terms: ['a'])).not_to eq(draft.add(main_terms: ['b']))
    end

    it '別の種類のものとは等しくありません' do
      expect(draft).not_to eq({ input: input })
    end
  end

  describe '#to_h' do
    it 'すべての項目を返します' do
      expect(draft.to_h.keys)
        .to contain_exactly(:input, :main_terms, :negative_terms, :notes, :dictionary_version)
    end
  end
end
