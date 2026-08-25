# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  def build_user(**overrides)
    described_class.new({ x_user_id: '1234567890', display_name: 'あお' }.merge(overrides))
  end

  describe '検証' do
    it '識別子と表示名がそろえば保存できます' do
      expect(build_user).to be_valid
    end

    it '識別子が無ければ保存できません' do
      expect(build_user(x_user_id: nil)).not_to be_valid
    end

    it '識別子は数字のみです' do
      expect(build_user(x_user_id: 'ao_design')).not_to be_valid
    end

    it '表示名が無ければ保存できません' do
      expect(build_user(display_name: nil)).not_to be_valid
    end

    it '同じ識別子を二重に保存できません' do
      build_user.save!

      expect(build_user(display_name: 'べつのひと')).not_to be_valid
    end
  end

  describe 'プラン値' do
    it '初期値は判定前です' do
      expect(build_user.plan).to eq('unverified')
    end

    it '定義されていない値を受け付けません' do
      expect(build_user(plan: 'unknown')).not_to be_valid
    end

    it '利用できる状態のときだけ許可します' do
      expect(build_user(plan: 'active').authorized?).to be(true)
    end

    it '判定前は許可しません' do
      expect(build_user(plan: 'unverified').authorized?).to be(false)
    end

    it '条件を満たしていない状態は許可しません' do
      expect(build_user(plan: 'pending').authorized?).to be(false)
    end
  end

  describe '個人情報' do
    it 'メールアドレス・住所・電話番号を保持しません' do
      columns = described_class.column_names

      expect(columns).not_to include('email', 'address', 'phone', 'phone_number')
    end

    it '保持するのは識別子・表示名・プラン値のみです' do
      columns = described_class.column_names - %w[id created_at updated_at]

      expect(columns).to contain_exactly('x_user_id', 'display_name', 'plan')
    end
  end
end
