# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QuotaConsumption do
  let(:user) { User.create!(x_user_id: '1234567890', display_name: 'あお') }
  let(:other_user) { User.create!(x_user_id: '9876543210', display_name: 'みどり') }
  let(:quota_day) { Date.new(2026, 8, 25) }

  def build_consumption(**overrides)
    described_class.new({ user: user, quota_day: quota_day }.merge(overrides))
  end

  describe '検証' do
    it '利用者とクォータ日があれば保存できます' do
      expect(build_consumption).to be_valid
    end

    it '利用者が無ければ保存できません' do
      expect(build_consumption(user: nil)).not_to be_valid
    end

    it 'クォータ日が無ければ保存できません' do
      expect(build_consumption(quota_day: nil)).not_to be_valid
    end

    it '定義されていない状態は保存できません' do
      expect(build_consumption(status: 'unknown')).not_to be_valid
    end

    it '既定の状態は予約です' do
      expect(build_consumption.status).to eq('reserved')
    end

    it '手動リセットの記録は既定で立っていません' do
      expect(build_consumption.reset_by_admin).to be(false)
    end
  end

  describe '1アカウント1日1回' do
    it '同じ利用者の同じ日は2件目を保存できません' do
      build_consumption.save!

      expect(build_consumption).not_to be_valid
    end

    it '日が違えば保存できます' do
      build_consumption.save!

      expect(build_consumption(quota_day: quota_day + 1)).to be_valid
    end

    it '利用者が違えば同じ日でも保存できます' do
      build_consumption.save!

      expect(build_consumption(user: other_user)).to be_valid
    end

    it '検証を飛ばしても、データベースが2件目を弾きます' do
      build_consumption.save!

      expect { build_consumption.save!(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe '並列投入' do
    # 別々の接続から同時に投入する様子を確かめます。接続をまたぐため、
    # この例だけはテストごとのトランザクションを使いません。
    self.use_transactional_tests = false

    let!(:parallel_user) { User.create!(x_user_id: '1122334455', display_name: 'あかね') }

    after do
      described_class.where(user_id: parallel_user.id).find_each(&:destroy!)
      parallel_user.destroy!
    end

    # 別々の接続から1件ずつ投入します。通れば accepted、弾かれれば blocked です。
    def attempt(results)
      ActiveRecord::Base.connection_pool.with_connection do
        described_class.create!(user_id: parallel_user.id, quota_day: quota_day)
        results << :accepted
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        results << :blocked
      end
    end

    # 同時に投入し、結果を集めます。
    def invade(count)
      results = Queue.new
      Array.new(count) { Thread.new { attempt(results) } }.each(&:join)

      Array.new(results.size) { results.pop }
    end

    it '同時に投入しても1件しか通りません' do
      outcomes = invade(4)

      expect(outcomes.count(:accepted)).to eq(1)
      expect(outcomes.count(:blocked)).to eq(3)
      expect(described_class.where(user_id: parallel_user.id).count).to eq(1)
    end
  end

  describe '状態遷移' do
    let(:consumption) { build_consumption.tap(&:save!) }

    it '予約から確定へ進めます' do
      consumption.transition_to!('confirmed')

      expect(consumption.status).to eq('confirmed')
    end

    it '予約から返還へ進めます' do
      consumption.transition_to!('refunded')

      expect(consumption.status).to eq('refunded')
    end

    it '返還のあと、同じ日にもう一度予約できます' do
      consumption.transition_to!('refunded')
      consumption.transition_to!('reserved')

      expect(consumption.status).to eq('reserved')
      expect(described_class.where(user_id: user.id, quota_day: quota_day).count).to eq(1)
    end

    it '確定したものは動かせません' do
      consumption.transition_to!('confirmed')

      expect { consumption.transition_to!('refunded') }
        .to raise_error(described_class::InvalidTransitionError)
    end

    it '予約から予約へは進めません' do
      expect { consumption.transition_to!('reserved') }
        .to raise_error(described_class::InvalidTransitionError)
    end

    it '遷移と同時に属性を書き込めます' do
      request = PromptRequest.create!(
        project: Project.create!(user: user, industry: 'saas', style_family: 'photoreal'),
        target_model: 'midjourney'
      )

      consumption.transition_to!('confirmed', prompt_request: request)

      expect(consumption.prompt_request).to eq(request)
    end
  end

  describe '#consuming?' do
    it '予約は枠を使っています' do
      expect(build_consumption(status: 'reserved')).to be_consuming
    end

    it '確定は枠を使っています' do
      expect(build_consumption(status: 'confirmed')).to be_consuming
    end

    it '返還は枠を使っていません' do
      expect(build_consumption(status: 'refunded')).not_to be_consuming
    end
  end

  describe '.find_for' do
    it 'その日の消費を返します' do
      consumption = build_consumption.tap(&:save!)

      expect(described_class.find_for(user, quota_day)).to eq(consumption)
    end

    it '無ければ空を返します' do
      expect(described_class.find_for(user, quota_day)).to be_nil
    end

    it '他人の消費は返しません' do
      build_consumption.save!

      expect(described_class.find_for(other_user, quota_day)).to be_nil
    end
  end

  describe '生成リクエストとの結び付き' do
    it '予約した時点では結び付いていません' do
      expect(build_consumption.tap(&:save!).prompt_request).to be_nil
    end
  end
end
