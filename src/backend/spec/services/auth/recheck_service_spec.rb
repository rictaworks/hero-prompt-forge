# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::RecheckService do
  subject(:service) { described_class.new(plan_updater: plan_updater, clock: clock) }

  let(:plan_updater) { instance_double(Auth::PlanUpdater) }
  let(:now) { Time.zone.parse('2026-08-25T10:00:00+09:00') }
  let(:clock) { class_double(Time, current: now) }
  let(:user) { User.create!(x_user_id: '1234567890', display_name: 'あお') }

  before { allow(plan_updater).to receive(:refresh).and_return(true) }

  describe '#call' do
    it '判定を取り直します' do
      service.call(user)

      expect(plan_updater).to have_received(:refresh).with(user)
    end

    it '次に要求できる時刻を立てます' do
      service.call(user)

      expect(user.reload.recheck_available_at).to eq(now + described_class::COOLDOWN)
    end

    it '判定した時刻を記録します' do
      service.call(user)

      expect(user.reload.plan_checked_at).to eq(now)
    end

    it '反映したかどうかを返します' do
      expect(service.call(user)).to be(true)
    end
  end

  describe 'クールダウン' do
    it 'クールダウン中は要求できません' do
      user.update!(recheck_available_at: now + 1.minute)

      expect { service.call(user) }.to raise_error(described_class::CooldownError)
    end

    it 'クールダウン中は判定サービスを呼びません' do
      user.update!(recheck_available_at: now + 1.minute)

      expect { service.call(user) }.to raise_error(described_class::CooldownError)

      expect(plan_updater).not_to have_received(:refresh)
    end

    it 'いつ要求できるかを伝えます' do
      available_at = now + 1.minute
      user.update!(recheck_available_at: available_at)

      service.call(user)
    rescue described_class::CooldownError => e
      expect(e.available_at).to eq(available_at)
    end

    it 'クールダウンが明ければ要求できます' do
      user.update!(recheck_available_at: now - 1.second)

      expect { service.call(user) }.not_to raise_error
    end

    it '境界の時刻では要求できません' do
      user.update!(recheck_available_at: now + 1.second)

      expect { service.call(user) }.to raise_error(described_class::CooldownError)
    end

    it '判定が失敗しても、連続した要求を許しません' do
      allow(plan_updater).to receive(:refresh).and_return(false)

      service.call(user)

      expect(user.reload.recheck_available_at).to eq(now + described_class::COOLDOWN)
    end
  end

  describe '#cooldown_seconds' do
    it '要求できる場合は 0 を返します' do
      expect(service.cooldown_seconds(user)).to eq(0)
    end

    it '残りの秒数を返します' do
      user.update!(recheck_available_at: now + 90.seconds)

      expect(service.cooldown_seconds(user)).to eq(90)
    end

    it '一度も要求していない場合は 0 を返します' do
      expect(service.cooldown_seconds(User.new)).to eq(0)
    end
  end
end
