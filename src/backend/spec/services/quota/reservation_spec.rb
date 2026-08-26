# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Quota::Reservation do
  let(:user) { User.create!(x_user_id: '1234567890', display_name: 'あお') }
  let(:project) { Project.create!(user: user, industry: 'saas', style_family: 'photoreal') }
  let(:prompt_request) { PromptRequest.create!(project: project, target_model: 'midjourney') }
  # クォータ日 2026-08-25 のまん中です。
  let(:now) { Time.find_zone!('Asia/Tokyo').parse('2026-08-25 12:00:00') }

  describe '.reserve!' do
    it 'その日の枠を予約します' do
      consumption = described_class.reserve!(user: user, now: now)

      expect(consumption.quota_day).to eq(Date.new(2026, 8, 25))
      expect(consumption.status).to eq('reserved')
    end

    it '境界の前は前日の枠を使います' do
      early = Time.find_zone!('Asia/Tokyo').parse('2026-08-26 02:59:00')

      expect(described_class.reserve!(user: user, now: early).quota_day)
        .to eq(Date.new(2026, 8, 25))
    end

    it '同じ日に二度目は予約できません' do
      described_class.reserve!(user: user, now: now)

      expect { described_class.reserve!(user: user, now: now) }
        .to raise_error(described_class::ExhaustedError)
    end

    it '上限に達したときは次回のリセット時刻を添えます' do
      described_class.reserve!(user: user, now: now)

      expect { described_class.reserve!(user: user, now: now) }
        .to raise_error(described_class::ExhaustedError) { |error|
          expect(error.reset_at).to eq(Time.find_zone!('Asia/Tokyo').parse('2026-08-26 03:00:00'))
          expect(error.quota_day).to eq(Date.new(2026, 8, 25))
        }
    end

    it '確定済みでも二度目は予約できません' do
      described_class.reserve!(user: user, now: now).transition_to!('confirmed')

      expect { described_class.reserve!(user: user, now: now) }
        .to raise_error(described_class::ExhaustedError)
    end

    it '日が変われば予約できます' do
      described_class.reserve!(user: user, now: now)
      next_day = Time.find_zone!('Asia/Tokyo').parse('2026-08-26 03:00:00')

      expect(described_class.reserve!(user: user, now: next_day).quota_day)
        .to eq(Date.new(2026, 8, 26))
    end

    it '生成リクエストを結び付けられます' do
      consumption = described_class.reserve!(user: user, prompt_request: prompt_request, now: now)

      expect(consumption.prompt_request).to eq(prompt_request)
    end

    it '他人の生成リクエストへは結び付けられません' do
      stranger = User.create!(x_user_id: '5555555555', display_name: 'しろ')

      expect { described_class.reserve!(user: stranger, prompt_request: prompt_request, now: now) }
        .to raise_error(described_class::ForeignRequestError)
    end

    it '他人の生成リクエストを渡したときは枠を使いません' do
      stranger = User.create!(x_user_id: '5555555555', display_name: 'しろ')

      expect { described_class.reserve!(user: stranger, prompt_request: prompt_request, now: now) }
        .to raise_error(described_class::ForeignRequestError)
      expect(QuotaConsumption.where(user_id: stranger.id).count).to eq(0)
    end

    it '同じ生成リクエストの予約は繰り返し呼んでも増えません' do
      first = described_class.reserve!(user: user, prompt_request: prompt_request, now: now)
      second = described_class.reserve!(user: user, prompt_request: prompt_request, now: now)

      expect(second).to eq(first)
      expect(QuotaConsumption.where(user_id: user.id).count).to eq(1)
    end
  end

  describe '.settle!' do
    before { described_class.reserve!(user: user, prompt_request: prompt_request, now: now) }

    it '通常完了で確定します' do
      prompt_request.transition_to!('queued')
      prompt_request.transition_to!('generating')
      prompt_request.transition_to!('completed')

      described_class.settle!(prompt_request)

      expect(QuotaConsumption.find_by(prompt_request_id: prompt_request.id).status)
        .to eq('confirmed')
    end

    it '縮退完了でも確定します' do
      prompt_request.transition_to!('queued')
      prompt_request.transition_to!('generating')
      prompt_request.transition_to!('degraded_completed', degraded: true)

      described_class.settle!(prompt_request)

      expect(QuotaConsumption.find_by(prompt_request_id: prompt_request.id).status)
        .to eq('confirmed')
    end

    it '失敗で返還します' do
      prompt_request.transition_to!('queued')
      prompt_request.transition_to!('generating')
      prompt_request.transition_to!('failed')

      described_class.settle!(prompt_request)

      expect(QuotaConsumption.find_by(prompt_request_id: prompt_request.id).status)
        .to eq('refunded')
    end

    it '生成の途中では確定も返還もしません' do
      prompt_request.transition_to!('queued')

      expect { described_class.settle!(prompt_request) }
        .to raise_error(described_class::NotSettleableError)
    end

    it '予約が無ければ失敗します' do
      other = PromptRequest.create!(project: project, target_model: 'dalle')
      other.transition_to!('queued')
      other.transition_to!('generating')
      other.transition_to!('completed')

      expect { described_class.settle!(other) }.to raise_error(described_class::MissingReservationError)
    end
  end

  describe '返還のあとの作り直し' do
    it '同じ日にもう一度予約できます' do
      described_class.reserve!(user: user, prompt_request: prompt_request, now: now)
      prompt_request.transition_to!('queued')
      prompt_request.transition_to!('generating')
      prompt_request.transition_to!('failed')
      described_class.settle!(prompt_request)

      consumption = described_class.reserve!(user: user, prompt_request: prompt_request, now: now)

      expect(consumption.status).to eq('reserved')
      expect(QuotaConsumption.where(user_id: user.id).count).to eq(1)
    end

    it '作り直しても記録は増えません' do
      described_class.reserve!(user: user, now: now).transition_to!('refunded')

      described_class.reserve!(user: user, now: now)

      expect(QuotaConsumption.where(user_id: user.id).count).to eq(1)
    end
  end

  describe '禁止入力' do
    it '差し戻したリクエストは枠を使いません' do
      prompt_request.transition_to!('rejected', rejection_reason: 'forbidden_input')

      expect { described_class.settle!(prompt_request) }
        .to raise_error(described_class::MissingReservationError)
      expect(QuotaConsumption.where(user_id: user.id).count).to eq(0)
    end
  end

  describe '.remaining_for?' do
    it '使っていなければ残っています' do
      expect(described_class.remaining_for?(user, now: now)).to be(true)
    end

    it '予約済みなら残っていません' do
      described_class.reserve!(user: user, now: now)

      expect(described_class.remaining_for?(user, now: now)).to be(false)
    end

    it '返還済みなら残っています' do
      described_class.reserve!(user: user, now: now).transition_to!('refunded')

      expect(described_class.remaining_for?(user, now: now)).to be(true)
    end
  end
end
