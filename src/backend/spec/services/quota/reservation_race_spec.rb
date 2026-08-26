# frozen_string_literal: true

require 'rails_helper'

# 返還済みの枠を、別々の接続から同時に取り直した場合の確かめです。
# 接続をまたぐため、テストごとのトランザクションを使いません。
RSpec.describe Quota::Reservation do
  self.use_transactional_tests = false

  let(:user) { User.create!(x_user_id: '7777777777', display_name: 'くろ') }
  let(:project) { Project.create!(user: user, industry: 'saas', style_family: 'photoreal') }
  # クォータ日 2026-08-25 のまん中です。
  let(:now) { Time.find_zone!('Asia/Tokyo').parse('2026-08-25 12:00:00') }

  before do
    QuotaConsumption.create!(user: user, quota_day: Quota::QuotaDay.of(now), status: 'refunded')
  end

  after do
    QuotaConsumption.where(user_id: user.id).find_each(&:destroy!)
    PromptRequest.where(project_id: project.id).find_each(&:destroy!)
    project.destroy!
    user.destroy!
  end

  # 別々の接続から1件ずつ取り直します。
  def try_reserve(results)
    ActiveRecord::Base.connection_pool.with_connection do
      request = PromptRequest.create!(project: project, target_model: 'midjourney')
      described_class.reserve!(user: user, prompt_request: request, now: now)
      results << :accepted
    rescue described_class::ExhaustedError
      results << :blocked
    end
  end

  # 同時に取り直し、結果を集めます。
  def race(count)
    results = Queue.new
    Array.new(count) { Thread.new { try_reserve(results) } }.each(&:join)

    Array.new(results.size) { results.pop }
  end

  it '予約が成立するのは1件だけです' do
    outcomes = race(4)

    expect(outcomes.count(:accepted)).to eq(1)
    expect(outcomes.count(:blocked)).to eq(3)
  end

  it '枠の記録は1件のままです' do
    race(4)

    expect(QuotaConsumption.where(user_id: user.id).count).to eq(1)
  end
end
