# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RuleDictionary do
  def build_dictionary(**overrides)
    described_class.new({ version: 'v2026.08.1' }.merge(overrides))
  end

  describe '検証' do
    it '版があれば保存できます' do
      expect(build_dictionary).to be_valid
    end

    it '版が無ければ保存できません' do
      expect(build_dictionary(version: nil)).not_to be_valid
    end

    it '同じ版を二重に保存できません' do
      build_dictionary.save!

      expect(build_dictionary).not_to be_valid
    end
  end

  describe '公開' do
    it '作成した直後は未公開です' do
      expect(build_dictionary.tap(&:save!)).not_to be_published
    end

    it '公開すると時刻が入ります' do
      dictionary = build_dictionary.tap(&:save!)

      dictionary.publish!

      expect(dictionary.published_at).to be_present
    end

    it '二度公開できません' do
      dictionary = build_dictionary.tap(&:save!)
      dictionary.publish!

      expect { dictionary.publish! }.to raise_error(described_class::PublishedVersionError)
    end
  end

  describe '公開済みの版' do
    subject(:dictionary) do
      build_dictionary(anti_ai_rules: { 'forbidden_terms' => ['a'] }).tap do |d|
        d.save!
        d.publish!
      end
    end

    it '書き換えられません' do
      dictionary.anti_ai_rules = { 'forbidden_terms' => %w[a b] }

      expect { dictionary.save! }.to raise_error(described_class::PublishedVersionError)
    end

    it '書き換えを試みても内容は変わりません' do
      dictionary.update(anti_ai_rules: { 'forbidden_terms' => %w[a b] })
    rescue described_class::PublishedVersionError
      expect(dictionary.reload.anti_ai_rules).to eq('forbidden_terms' => ['a'])
    end
  end

  describe '.current' do
    it '公開済みの最新の版を返します' do
      old = build_dictionary(version: 'v1').tap(&:save!)
      old.publish!(now: 2.days.ago)
      recent = build_dictionary(version: 'v2').tap(&:save!)
      recent.publish!(now: 1.day.ago)

      expect(described_class.current).to eq(recent)
    end

    it '未公開の版は返しません' do
      build_dictionary(version: 'v1').save!

      expect(described_class.current).to be_nil
    end

    it '未来に公開予定の版は返しません' do
      future = build_dictionary(version: 'v1').tap(&:save!)
      future.publish!(now: 1.day.from_now)

      expect(described_class.current).to be_nil
    end
  end

  describe '#defaults_for' do
    subject(:dictionary) do
      build_dictionary(industry_defaults: { 'saas' => { 'tone' => 'trust' } })
    end

    it '業種の既定値を返します' do
      expect(dictionary.defaults_for('saas')).to eq('tone' => 'trust')
    end

    it '定義が無ければ例外にします' do
      expect { dictionary.defaults_for('unknown') }.to raise_error(KeyError)
    end
  end

  describe '初期の内容' do
    before { load Rails.root.join('db/seeds.rb') }

    it '初期の版が公開されます' do
      expect(described_class.current).to be_present
    end

    it '排除する語と、対応するネガティブプロンプトを持ちます' do
      rules = described_class.current.anti_ai_rules

      expect(rules['forbidden_terms']).to be_present
      expect(rules['negative_prompt_terms']).to be_present
    end

    it '実写系は撮影指示を必須とします' do
      required = described_class.current.style_spec_rules.dig('photoreal', 'required')

      expect(required).to include('lens_mm', 'key_light', 'fill_light', 'rim_light',
                                  'depth_of_field')
    end

    it '仕様の業種をすべて持ちます' do
      expect(described_class.current.industry_defaults.keys).to contain_exactly(
        'saas', 'restaurant', 'medical', 'education', 'real_estate',
        'manufacturing', 'professional_services', 'ecommerce', 'beauty', 'other'
      )
    end

    it '二度実行しても増えません' do
      expect { load Rails.root.join('db/seeds.rb') }.not_to change(described_class, :count)
    end
  end
end
