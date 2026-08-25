# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Project do
  let(:user) { User.create!(x_user_id: '1234567890', display_name: 'あお') }
  let(:other) { User.create!(x_user_id: '9876543210', display_name: 'べつのひと') }

  def build_project(owner: user, **overrides)
    described_class.new({ user: owner, industry: 'saas', style_family: 'photoreal' }
      .merge(overrides))
  end

  describe '検証' do
    it '業種とスタイル系統がそろえば保存できます' do
      expect(build_project).to be_valid
    end

    it 'サイト名は任意です' do
      expect(build_project(name: nil)).to be_valid
    end

    it '業種が無ければ保存できません' do
      expect(build_project(industry: nil)).not_to be_valid
    end

    it '定義されていない業種を受け付けません' do
      expect(build_project(industry: 'unknown')).not_to be_valid
    end

    it 'スタイル系統が無ければ保存できません' do
      expect(build_project(style_family: nil)).not_to be_valid
    end

    it '定義されていないスタイル系統を受け付けません' do
      expect(build_project(style_family: 'watercolor')).not_to be_valid
    end

    it '所有者が無ければ保存できません' do
      expect(build_project(owner: nil)).not_to be_valid
    end

    it 'サイト名が長すぎる場合は保存できません' do
      expect(build_project(name: 'あ' * 101)).not_to be_valid
    end
  end

  describe '選択肢' do
    it '仕様の業種をすべて持ちます' do
      expect(described_class::INDUSTRIES).to contain_exactly(
        'saas', 'restaurant', 'medical', 'education', 'real_estate',
        'manufacturing', 'professional_services', 'ecommerce', 'beauty', 'other'
      )
    end

    it '仕様のスタイル系統をすべて持ちます' do
      expect(described_class::STYLE_FAMILIES)
        .to contain_exactly('photoreal', 'illustration', 'three_d', 'abstract')
    end
  end

  describe '他人のプロジェクト' do
    it '所有者で絞り込めます' do
      mine = build_project.tap(&:save!)
      build_project(owner: other).save!

      expect(described_class.for_user(user)).to contain_exactly(mine)
    end

    it '他人のものは絞り込みに含まれません' do
      theirs = build_project(owner: other).tap(&:save!)

      expect(described_class.for_user(user)).not_to include(theirs)
    end
  end

  describe '並び' do
    it '新しいものから並びます' do
      old = build_project.tap(&:save!)
      old.update_column(:created_at, 2.days.ago) # rubocop:disable Rails/SkipsModelValidations
      recent = build_project.tap(&:save!)

      expect(described_class.for_user(user).recent_first.to_a).to eq([recent, old])
    end
  end

  describe 'ブランドの設定' do
    it '既定は空です' do
      expect(build_project.tap(&:save!).brand_settings).to eq({})
    end

    it 'トーンとカラーを保持できます' do
      project = build_project(brand_settings: { 'tone' => 'trust',
                                                'colors' => %w[#c0392b #c9a84c] })
      project.save!

      expect(project.reload.brand_settings['colors']).to eq(%w[#c0392b #c9a84c])
    end
  end
end
