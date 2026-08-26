# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preset do
  let(:user) { User.create!(x_user_id: '1234567890', display_name: 'あお') }
  let(:other) { User.create!(x_user_id: '9876543210', display_name: 'べつのひと') }

  def build_preset(owner: user, **overrides)
    described_class.new({ user: owner, name: 'SaaS の定番' }.merge(overrides))
  end

  describe '検証' do
    it '名前があれば保存できます' do
      expect(build_preset).to be_valid
    end

    it '名前が無ければ保存できません' do
      expect(build_preset(name: nil)).not_to be_valid
    end

    it '名前が長すぎる場合は保存できません' do
      expect(build_preset(name: 'あ' * 51)).not_to be_valid
    end

    it '同じ人が同じ名前を二重に持てません' do
      build_preset.save!

      expect(build_preset).not_to be_valid
    end

    it '別の人なら同じ名前を持てます' do
      build_preset.save!

      expect(build_preset(owner: other)).to be_valid
    end

    it '所有者が無ければ保存できません' do
      expect(build_preset(owner: nil)).not_to be_valid
    end
  end

  describe '入力条件' do
    it '許した項目だけを保存できます' do
      preset = build_preset(input_conditions: { 'industry' => 'saas',
                                                'style_family' => 'photoreal' })

      expect(preset).to be_valid
    end

    it '許していない項目があれば保存できません' do
      preset = build_preset(input_conditions: { 'industry' => 'saas',
                                                'secret_flag' => true })

      expect(preset).not_to be_valid
    end

    it '空でも保存できます' do
      expect(build_preset(input_conditions: {})).to be_valid
    end

    it '保存した条件を取り出せます' do
      preset = build_preset(input_conditions: { 'aspect_ratio' => '16:9' })
      preset.save!

      expect(preset.reload.input_conditions['aspect_ratio']).to eq('16:9')
    end

    it '仕様の入力項目をすべて許します' do
      expect(described_class::ALLOWED_CONDITION_KEYS).to contain_exactly(
        'industry', 'style_family', 'target_model', 'service_summary',
        'brand_tone', 'brand_colors', 'copy_space_position', 'aspect_ratio'
      )
    end
  end

  # **鍵を絞っても、値の大きさは絞れません**（PR #167 のレビューより）。
  describe '入力条件の大きさ' do
    it '上限を越える大きさは保存できません' do
      long = 'あ' * (described_class::MAX_CONDITIONS_LENGTH + 1)
      preset = described_class.new(user: user, name: '長すぎる条件',
                                   input_conditions: { 'service_summary' => long })

      expect(preset).not_to be_valid
    end

    it '上限までなら保存できます' do
      fitting = 'あ' * 100
      preset = described_class.new(user: user, name: 'ふつうの条件',
                                   input_conditions: { 'service_summary' => fitting })

      expect(preset).to be_valid
    end
  end

  describe '他人のプリセット' do
    it '所有者で絞り込めます' do
      mine = build_preset.tap(&:save!)
      build_preset(owner: other).save!

      expect(described_class.for_user(user)).to contain_exactly(mine)
    end

    it '他人のものは絞り込みに含まれません' do
      theirs = build_preset(owner: other).tap(&:save!)

      expect(described_class.for_user(user)).not_to include(theirs)
    end
  end

  describe '並び' do
    it '名前の順に並びます' do
      second = build_preset(name: 'びより').tap(&:save!)
      first = build_preset(name: 'あさひ').tap(&:save!)

      expect(described_class.for_user(user).by_name.to_a).to eq([first, second])
    end
  end
end
