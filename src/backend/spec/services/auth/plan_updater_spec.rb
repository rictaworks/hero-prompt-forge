# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::PlanUpdater do
  subject(:updater) { described_class.new(gate_client: gate_client) }

  let(:gate_client) { instance_double(FollowerGateClient) }
  let(:user) { User.create!(x_user_id: '1234567890', display_name: 'あお') }

  def decision(plan:, confirmed: true)
    FollowerGateClient::Decision.new(plan: plan, confirmed: confirmed,
                                     decided_at: '2026-08-25T10:00:00+09:00',
                                     recheck_available: false, inquiry_id: nil)
  end

  describe '#refresh' do
    it '判定サービスが full を返せば利用できる状態にします' do
      allow(gate_client).to receive(:decide).and_return(decision(plan: 'full'))

      updater.refresh(user)

      expect(user.reload.plan).to eq('active')
    end

    it '判定サービスが restricted を返せば条件を満たさない状態にします' do
      allow(gate_client).to receive(:decide).and_return(decision(plan: 'restricted'))

      updater.refresh(user)

      expect(user.reload.plan).to eq('pending')
    end

    it '識別子を渡して判定を求めます' do
      allow(gate_client).to receive(:decide).and_return(decision(plan: 'full'))

      updater.refresh(user)

      expect(gate_client).to have_received(:decide).with(x_user_id: '1234567890')
    end

    it '反映したときは true を返します' do
      allow(gate_client).to receive(:decide).and_return(decision(plan: 'full'))

      expect(updater.refresh(user)).to be(true)
    end
  end

  describe '判定サービスの障害時' do
    before do
      allow(gate_client).to receive(:decide).and_raise(FollowerGateClient::UnavailableError)
    end

    it '利用できる状態を維持します' do
      user.update!(plan: 'active')

      updater.refresh(user)

      expect(user.reload.plan).to eq('active')
    end

    it '判定前の状態も変えません' do
      updater.refresh(user)

      expect(user.reload.plan).to eq('unverified')
    end

    it '条件を満たさない状態を、勝手に利用できる状態にしません' do
      user.update!(plan: 'pending')

      updater.refresh(user)

      expect(user.reload.plan).to eq('pending')
    end

    it '反映しなかったことを false で伝えます' do
      expect(updater.refresh(user)).to be(false)
    end
  end

  describe '#apply' do
    it '確定していない判定では値を変えません' do
      user.update!(plan: 'active')

      result = updater.apply(user, decision(plan: 'restricted', confirmed: false))

      expect([result, user.reload.plan]).to eq([false, 'active'])
    end

    it '未知のプラン値は例外にします' do
      expect { updater.apply(user, decision(plan: 'unknown')) }
        .to raise_error(described_class::UnknownPlanError)
    end

    it '未知のプラン値のときは値を変えません' do
      user.update!(plan: 'active')

      expect { updater.apply(user, decision(plan: 'unknown')) }
        .to raise_error(described_class::UnknownPlanError)

      expect(user.reload.plan).to eq('active')
    end
  end

  describe '状態の遷移' do
    it '条件を満たさない状態から、再判定で利用できる状態になります' do
      user.update!(plan: 'pending')

      updater.apply(user, decision(plan: 'full'))

      expect(user.reload.plan).to eq('active')
    end

    it '再判定でも条件を満たさない場合は、そのままです' do
      user.update!(plan: 'pending')

      updater.apply(user, decision(plan: 'restricted'))

      expect(user.reload.plan).to eq('pending')
    end

    it '利用できる状態から、条件を満たさない状態へ戻せます' do
      user.update!(plan: 'active')

      updater.apply(user, decision(plan: 'restricted'))

      expect(user.reload.plan).to eq('pending')
    end
  end

  describe '機能側との境目' do
    it '機能側が参照するのはプラン値だけです' do
      allow(gate_client).to receive(:decide).and_return(decision(plan: 'full'))

      updater.refresh(user)

      expect(user.reload.authorized?).to be(true)
    end
  end
end
