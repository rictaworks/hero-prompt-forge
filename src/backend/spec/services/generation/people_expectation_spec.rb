# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::PeopleExpectation do
  let(:industry_defaults) do
    { 'saas' => { 'tone' => 'trust', 'people' => 'expected' },
      'ecommerce' => { 'tone' => 'friendly', 'people' => 'unlikely' } }
  end

  let(:dictionary) do
    RuleDictionary.create!(version: 'vspec.people',
                           anti_ai_rules: InitialRuleDictionary.anti_ai_rules,
                           industry_defaults: industry_defaults)
  end

  def people(override: nil)
    described_class.new(dictionary: dictionary, override: override)
  end

  # **業種の既定値から引きます**（issue #139）。
  describe '業種の既定値' do
    it '写る見込みの業種を見分けます' do
      expect(people.expected?('saas')).to be(true)
    end

    it '写らない見込みの業種を見分けます' do
      expect(people.expected?('ecommerce')).to be(false)
    end

    it '出どころが業種であることを返します' do
      expect(people.decide('saas')[:source]).to eq(described_class::FROM_INDUSTRY)
    end

    it '引いた値も返します' do
      expect(people.decide('saas')[:value]).to eq(described_class::EXPECTED)
    end
  end

  # **プロジェクト単位で上書きできます**（issue #147）。
  describe 'プロジェクト単位の上書き' do
    it '写らない見込みの業種を、写る側へ寄せられます' do
      expect(people(override: 'expected').expected?('ecommerce')).to be(true)
    end

    it '写る見込みの業種を、写らない側へ寄せられます' do
      expect(people(override: 'unlikely').expected?('saas')).to be(false)
    end

    it '出どころがプロジェクトであることを返します' do
      expect(people(override: 'expected').decide('ecommerce')[:source])
        .to eq(described_class::FROM_PROJECT)
    end

    # **上書きがあれば、業種の既定値を引きません。**
    it '業種の既定値が無くても答えられます' do
      expect(people(override: 'expected').expected?('unknown_industry')).to be(true)
    end
  end

  # **選択肢の外の値は、組み立ての時点で失敗させます。**
  describe '想定外の上書き' do
    ['maybe', '', 'Expected', 1, []].each do |value|
      it "「#{value.inspect}」なら組み立てで失敗します" do
        expect { people(override: value) }
          .to raise_error(described_class::InvalidOverrideError)
      end
    end

    # **例外に、利用者由来の値そのものを入れません。**
    it '例外に値そのものを入れません' do
      expect { people(override: '社外秘の値') }
        .to raise_error(described_class::InvalidOverrideError, /String/)
    end
  end

  # **規則辞書の定義が壊れていたら、その場で失敗させます。**
  describe '規則辞書の検め' do
    let(:industry_defaults) { { 'saas' => { 'tone' => 'trust' } } }

    it '見込みの定義が無ければ失敗します' do
      expect { people.expected?('saas') }
        .to raise_error(described_class::InvalidDictionaryError)
    end
  end

  describe '選択肢の外の既定値' do
    let(:industry_defaults) { { 'saas' => { 'tone' => 'trust', 'people' => 'maybe' } } }

    it '失敗します' do
      expect { people.expected?('saas') }
        .to raise_error(described_class::InvalidDictionaryError)
    end
  end
end
