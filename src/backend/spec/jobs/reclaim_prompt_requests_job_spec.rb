# frozen_string_literal: true

require 'rails_helper'

# 置き去りの生成リクエストの拾い直しです（issue #169）。
RSpec.describe ReclaimPromptRequestsJob do
  let(:user) { User.create!(x_user_id: '4444444444', display_name: 'きいろ', plan: 'active') }
  let(:project) { Project.create!(user: user, industry: 'saas', style_family: 'photoreal') }

  def request_in(status, updated: Time.current, reserve: true, created: nil)
    request = PromptRequest.create!(project: project, target_model: 'midjourney',
                                    inputs: {}, status: 'draft')
    Quota::Reservation.reserve!(user: user, prompt_request: request) if reserve
    advance(request, status)
    request.update_column(:updated_at, updated) # rubocop:disable Rails/SkipsModelValidations
    request.update_column(:created_at, created) if created # rubocop:disable Rails/SkipsModelValidations
    request
  end

  # **定めどおりに状態を進めます。** 直に書き換えません。
  def advance(request, status)
    request.transition_to!('queued')
    return if status == 'queued'

    request.transition_to!('generating')
    return if status == 'generating'

    request.transition_to!(status)
  end

  def enqueued_ids
    ActiveJob::Base.queue_adapter.enqueued_jobs
                   .select { |job| job[:job] == GeneratePromptJob }
                   .map { |job| job[:args].first }
  end

  before { ActiveJob::Base.queue_adapter = :test }

  describe '動きの無い行' do
    it '置き去りの行を投入し直します' do
      target = request_in('generating', updated: (described_class::STALE_AFTER + 1.minute).ago)

      described_class.perform_now

      expect(enqueued_ids).to include(target.id)
    end

    # **まだ走っているかもしれない行へ、横入りしません。**
    it '走り出したばかりの行は投入しません' do
      target = request_in('generating', updated: 10.seconds.ago)

      described_class.perform_now

      expect(enqueued_ids).not_to include(target.id)
    end

    it '順番待ちの行は投入しません' do
      target = request_in('queued', updated: 1.hour.ago)

      described_class.perform_now

      expect(enqueued_ids).not_to include(target.id)
    end
  end

  # **同じ場所で毎回落ちる行を、際限なく投入し続けません**（issue #181）。
  #
  # 5 分ごとの拾い直しに上限が無いと、働き手が同じ理由で毎回落ちる行
  # （例：メモリ不足）は `generating` のまま残り続け、拾い直しのたびに
  # 有償の呼び出しがかかります。**回数を数える列を増やさず、既にある
  # クォータ日の境界（`Quota::QuotaDay`）で見分けます。** 生成リクエストを
  # 作った時点のクォータ日と、いまのクォータ日がずれていれば、日をまたいで
  # も組み立てに進めていない行です。投入せず、失敗として打ち切ります。
  describe '日をまたいだ置き去りの行' do
    include ActiveSupport::Testing::TimeHelpers

    it '投入せず、失敗として打ち切ります' do
      travel_to Time.zone.parse('2026-08-29 10:00:00') do
        target = request_in('generating', updated: (described_class::STALE_AFTER + 1.minute).ago,
                                          created: Time.zone.parse('2026-08-28 20:00:00'))

        described_class.perform_now

        expect(enqueued_ids).not_to include(target.id)
        expect(target.reload.status).to eq('failed')
      end
    end

    it '枠を返します' do
      travel_to Time.zone.parse('2026-08-29 10:00:00') do
        target = request_in('generating', updated: (described_class::STALE_AFTER + 1.minute).ago,
                                          created: Time.zone.parse('2026-08-28 20:00:00'))

        described_class.perform_now

        expect(QuotaConsumption.find_by(prompt_request: target).status).to eq('refunded')
      end
    end

    it '理由の種別を残します' do
      travel_to Time.zone.parse('2026-08-29 10:00:00') do
        target = request_in('generating', updated: (described_class::STALE_AFTER + 1.minute).ago,
                                          created: Time.zone.parse('2026-08-28 20:00:00'))

        described_class.perform_now

        expect(target.reload.rejection_reason).to eq('ReclaimPromptRequestsJob::AbandonedError')
      end
    end

    # **クォータ日の境界は JST 03:00 です。** 日付だけでなく、境界の
    # 時刻をまたいだかどうかで見分けます。
    it '同じクォータ日のうちは、これまでどおり投入します' do
      travel_to Time.zone.parse('2026-08-29 10:00:00') do
        target = request_in('generating', updated: (described_class::STALE_AFTER + 1.minute).ago,
                                          created: Time.zone.parse('2026-08-29 04:00:00'), reserve: false)

        described_class.perform_now

        expect(enqueued_ids).to include(target.id)
        expect(target.reload.status).to eq('generating')
      end
    end

    # **決着だけが残っている行は対象外です。** 打ち切りは、組み立てに
    # 進めていない `generating` の行だけを対象にします。
    it '決着だけが残っている行は打ち切りません' do
      travel_to Time.zone.parse('2026-08-29 10:00:00') do
        target = request_in('completed', updated: 1.minute.ago,
                                         created: Time.zone.parse('2026-08-28 20:00:00'))

        described_class.perform_now

        expect(enqueued_ids).to include(target.id)
        expect(target.reload.status).to eq('completed')
      end
    end
  end

  describe '決着だけが残っている行' do
    # **確定・返還はひとまとまりの外で行いますので、そこで落ちるとこの形になります。**
    it '成果物を提供したのに枠が予約のままなら、投入し直します' do
      target = request_in('completed', updated: 1.minute.ago)

      described_class.perform_now

      expect(enqueued_ids).to include(target.id)
    end

    # **鏡像の側も拾います。**
    it '失敗として記録したのに枠が予約のままなら、投入し直します' do
      target = request_in('failed', updated: 1.minute.ago)

      described_class.perform_now

      expect(enqueued_ids).to include(target.id)
    end

    it '決着済みの行は投入しません' do
      target = request_in('completed', updated: 1.minute.ago)
      Quota::Reservation.settle!(target)

      described_class.perform_now

      expect(enqueued_ids).not_to include(target.id)
    end

    it '枠を使っていない行は投入しません' do
      target = request_in('completed', updated: 1.minute.ago, reserve: false)

      described_class.perform_now

      expect(enqueued_ids).not_to include(target.id)
    end
  end

  describe '一度に投入する数' do
    # **枠を取りません。** 同じ利用者は 1 日 1 回しか予約できません
    # （requirements.md 4.4）。ここで確かめたいのは投入の数です。
    it '上限を越えて投入しません' do
      stub_const("#{described_class}::BATCH_SIZE", 2)
      3.times { request_in('generating', updated: 1.hour.ago, reserve: false) }

      described_class.perform_now

      expect(enqueued_ids.size).to eq(2)
    end

    # **2 つの並びを足した数にも、上限が効きます。**
    #
    # 片方の並びだけで確かめると、**足したあとの上限を外しても緑のままです**
    # （PR #176 のレビュー・要修正 4）。**それぞれが上限まで拾った場面**を作ります。
    it '2 つの並びを足しても、上限を越えて投入しません' do
      stub_const("#{described_class}::BATCH_SIZE", 3)
      stale = Array.new(2) { request_in('generating', updated: 1.hour.ago, reserve: false).id }
      # **枠を取りません。** 同じ利用者は 1 日 1 回しか予約できません
      # （requirements.md 4.4）。ここで確かめたいのは投入の数です。
      unsettled = Array.new(2) { request_in('completed', updated: 1.minute.ago, reserve: false).id }
      job = described_class.new
      allow(job).to receive_messages(stale_ids: stale, unsettled_ids: unsettled)

      job.perform

      expect(enqueued_ids.size).to eq(3)
    end
  end

  describe '同じ行を二度投入しないこと' do
    # **2 つの並びに同じ行が入っても、投入は 1 回です。**
    #
    # **いまの 2 つの並びは、状態が重なりません。** 動きの無い行は `generating`、
    # 決着だけが残る行は `completed` ・ `degraded_completed` ・ `failed` です。
    # **ですので、実際のデータでは重なりを作れません**（PR #176 のレビュー・要修正 4）。
    # 拾う条件が広がった日に二重投入が起きないよう、**並びを直に与えて確かめます。**
    it '重なった行を 1 回だけ投入します' do
      target = request_in('generating', updated: 1.hour.ago)
      job = described_class.new
      allow(job).to receive_messages(stale_ids: [target.id], unsettled_ids: [target.id])

      job.perform

      expect(enqueued_ids.count(target.id)).to eq(1)
    end
  end

  describe '置き去りと見なすまでの時間' do
    # **書き写しません。** 片方だけを直すと、拾い直しが黙って発火しなくなります。
    it '生成のジョブと同じ値です' do
      expect(described_class::STALE_AFTER).to eq(GeneratePromptJob::STALE_AFTER)
    end
  end

  describe '定時の実行' do
    # **定時に走らせます**（issue #169）。一度見送られた回は、二度と投入されません。
    it '定時の設定に載っています' do
      schedule = YAML.safe_load_file(Rails.root.join('config/recurring.yml'), aliases: true)

      expect(schedule.fetch('production').keys).to include('reclaim_prompt_requests')
    end

    it '開発でも走ります' do
      schedule = YAML.safe_load_file(Rails.root.join('config/recurring.yml'), aliases: true)

      expect(schedule.fetch('development').keys).to include('reclaim_prompt_requests')
    end

    it '呼び出す先は、この持ち場です' do
      schedule = YAML.safe_load_file(Rails.root.join('config/recurring.yml'), aliases: true)

      expect(schedule.dig('production', 'reclaim_prompt_requests', 'class'))
        .to eq(described_class.name)
    end
  end
end
