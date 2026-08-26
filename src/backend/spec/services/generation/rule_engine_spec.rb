# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::RuleEngine do
  let(:dictionary) do
    RuleDictionary.create!(
      version: 'vspec.rules',
      anti_ai_rules: {
        'forbidden_terms' => ['purple to teal gradient', 'floating 3d shapes'],
        'negative_prompt_terms' => %w[oversaturation deformed_hands],
        'avoided_compositions' => ['large frontal face close-up']
      }
    )
  end

  let(:engine) { described_class.new(dictionary: dictionary) }
  let(:input) { { industry: 'saas', style_family: 'photoreal', target_model: 'midjourney' } }

  describe '#start' do
    it '入力を持つ下書きを起こします' do
      expect(engine.start(input).input).to eq(input)
    end

    it '規則辞書の版を記録します' do
      expect(engine.start(input).dictionary_version).to eq('vspec.rules')
    end

    it '素材は空から始まります' do
      draft = engine.start(input)

      expect(draft.main_terms).to be_empty
      expect(draft.negative_terms).to be_empty
    end
  end

  describe '#apply' do
    def applied(main_terms)
      engine.apply(engine.start(input).add(main_terms: main_terms))
    end

    it '排除する語をメインプロンプトから取り除きます' do
      draft = applied(['a calm office', 'purple to teal gradient'])

      expect(draft.main_terms).to eq(['a calm office'])
    end

    it '語を含む言い回しも取り除きます' do
      draft = applied(['purple to teal gradient background'])

      expect(draft.main_terms).to be_empty
    end

    it '排除する語が無ければそのまま残します' do
      draft = applied(['a calm office', 'soft window light'])

      expect(draft.main_terms).to eq(['a calm office', 'soft window light'])
    end

    it '注入する語をネガティブプロンプトへ入れます' do
      expect(applied(['a calm office']).negative_terms)
        .to include('oversaturation', 'deformed_hands')
    end

    it '注入する語は重ねません' do
      draft = engine.apply(engine.apply(engine.start(input).add(main_terms: ['a calm office'])))

      expect(draft.negative_terms.count('oversaturation')).to eq(1)
    end

    it '取り除いた語をノートへ残します' do
      draft = applied(['purple to teal gradient'])

      expect(draft.notes).to include(
        { kind: described_class::REMOVED_NOTE_KIND, term: 'purple to teal gradient' }
      )
    end

    it '取り除いていなければノートを増やしません' do
      expect(applied(['a calm office']).notes).to be_empty
    end

    it '規則辞書の版を記録します' do
      expect(applied(['a calm office']).dictionary_version).to eq('vspec.rules')
    end

    it '入力はそのまま持ち越します' do
      expect(applied(['a calm office']).input).to eq(input)
    end
  end

  describe '#avoided_compositions' do
    it '既定で避ける構図を返します' do
      expect(engine.avoided_compositions).to eq(['large frontal face close-up'])
    end

    it '定義が無ければ空を返します' do
      without_compositions = RuleDictionary.create!(
        version: 'vspec.no-compositions',
        anti_ai_rules: { 'forbidden_terms' => [], 'negative_prompt_terms' => [] }
      )

      expect(described_class.new(dictionary: without_compositions).avoided_compositions).to be_empty
    end
  end

  describe '規則辞書の不備' do
    it '辞書が無ければ組み立てられません' do
      expect { described_class.new(dictionary: nil) }
        .to raise_error(described_class::MissingDictionaryError)
    end

    it '排除する語の定義が無ければ失敗します' do
      broken = RuleDictionary.create!(version: 'vspec.broken-rules',
                                      anti_ai_rules: { 'negative_prompt_terms' => [] })

      expect { described_class.new(dictionary: broken) }
        .to raise_error(described_class::InvalidDictionaryError)
    end

    it '注入する語の定義が無ければ失敗します' do
      broken = RuleDictionary.create!(version: 'vspec.broken-rules2',
                                      anti_ai_rules: { 'forbidden_terms' => [] })

      expect { described_class.new(dictionary: broken) }
        .to raise_error(described_class::InvalidDictionaryError)
    end
  end

  describe '初期の規則辞書での適用' do
    before { load Rails.root.join('db/seeds.rb') }

    it '仕様が挙げるクリシェを排除します' do
      current = described_class.new(dictionary: RuleDictionary.current)
      draft = current.apply(
        current.start(input).add(main_terms: ['purple to teal gradient', 'a calm office'])
      )

      expect(draft.main_terms).to eq(['a calm office'])
    end

    it '破綻した手指を避ける語を注入します' do
      current = described_class.new(dictionary: RuleDictionary.current)
      draft = current.apply(current.start(input))

      expect(draft.negative_terms).to include('deformed hands')
    end
  end
end
