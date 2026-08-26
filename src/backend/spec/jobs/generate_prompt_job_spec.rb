# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GeneratePromptJob do
  let(:user) { User.create!(x_user_id: '2222222222', display_name: 'みどり') }
  let(:project) { Project.create!(user: user, industry: 'saas', style_family: 'photoreal') }

  let(:inputs) do
    { industry: 'saas', style_family: 'photoreal', target_model: 'midjourney',
      brand_tone: 'trust', copy_space_position: 'left', aspect_ratio: '16:9' }
  end

  let(:request) do
    PromptRequest.create!(project: project, target_model: 'midjourney', inputs: inputs)
  end

  def dictionary
    @dictionary ||= RuleDictionary.create!(
      version: 'vspec.job',
      anti_ai_rules: InitialRuleDictionary.anti_ai_rules,
      style_spec_rules: InitialRuleDictionary.style_spec_rules,
      industry_defaults: InitialRuleDictionary.industry_defaults
    ).tap(&:publish!)
  end

  def queued
    dictionary
    Quota::Reservation.reserve!(user: user, prompt_request: request)
    request.transition_to!('queued')
    request
  end

  def run
    described_class.perform_now(queued.id)
    request.reload
  end

  describe '成果物を提供できた場合' do
    it '3 案を保存します' do
      run

      expect(request.prompt_outputs.count).to eq(3)
    end

    it '案の番号を 1 から順に振ります' do
      run

      expect(request.prompt_outputs.in_order.pluck(:variation_no)).to eq([1, 2, 3])
    end

    it '構図の種別を残します' do
      run

      expect(request.prompt_outputs.in_order.pluck(:composition_type))
        .to eq(%w[subject_led environment_led abstract_background])
    end

    it '適用した規則辞書の版を残します' do
      expect(run.dictionary_version).to eq('vspec.job')
    end

    # **クォータは、ジョブの結果と一致させます。**
    it 'クォータを確定します' do
      run

      expect(QuotaConsumption.find_by(prompt_request: request).status).to eq('confirmed')
    end
  end

  # **縮退した案には印が残ります**（issue #53）。
  describe '磨けなかった場合' do
    it '縮退した状態にします' do
      expect(run.status).to eq('degraded_completed')
    end

    it '縮退の印を残します' do
      expect(run.degraded).to be(true)
    end

    # **成果物は提供しています。** クォータは確定します。
    it 'クォータを確定します' do
      run

      expect(QuotaConsumption.find_by(prompt_request: request).status).to eq('confirmed')
    end
  end

  # **繰り返しても結果が変わらない誤りは、その場で失敗として記録します。**
  describe '決まった結果になる誤り' do
    let(:inputs) { super().merge(industry: 'unknown') }

    it '失敗として記録します' do
      run

      expect(request.reload.status).to eq('failed')
    end

    it '理由の種別を残します' do
      run

      expect(request.reload.rejection_reason)
        .to eq('Generation::InputNormalizer::InvalidInputError')
    end

    # **クォータを返します。** 当日中に作り直していただけます。
    it 'クォータを返します' do
      run

      expect(QuotaConsumption.find_by(prompt_request: request).status).to eq('refunded')
    end

    it '案を残しません' do
      run

      expect(request.reload.prompt_outputs).to be_empty
    end
  end

  describe '禁止入力' do
    let(:inputs) { super().merge(service_summary: '他社のロゴを大きく掲載してください。') }

    it '失敗として記録します' do
      run

      expect(request.reload.status).to eq('failed')
    end

    it '理由の種別を残します' do
      run

      expect(request.reload.rejection_reason)
        .to eq('Generation::PromptGenerationService::ForbiddenInputError')
    end
  end

  # **リトライの上限を決めます。**
  describe 'リトライ' do
    it '上限が決まっています' do
      expect(described_class::MAX_ATTEMPTS).to eq(3)
    end

    # **繰り返せば通ることがある誤りは、上限まで試します。**
    # その場では失敗として記録しません。
    it '繰り返すべき誤りは、その場で失敗として記録しません' do
      allow(RuleDictionary).to receive(:current!).and_raise(ActiveRecord::ConnectionNotEstablished)
      described_class.perform_now(queued.id)

      expect(request.reload.status).to eq('generating')
    end

    it '繰り返すべき誤りは、投入し直します' do
      allow(RuleDictionary).to receive(:current!).and_raise(ActiveRecord::ConnectionNotEstablished)

      expect { described_class.perform_now(queued.id) }
        .to have_enqueued_job(described_class)
    end

    # **上限に達したら、失敗として記録します。**
    it '上限に達したら、失敗として記録します' do
      allow(RuleDictionary).to receive(:current!).and_raise(ActiveRecord::ConnectionNotEstablished)
      described_class.new(queued.id).record_failure(ActiveRecord::ConnectionNotEstablished.new)

      expect(request.reload.status).to eq('failed')
    end

    it '上限に達したら、クォータを返します' do
      allow(RuleDictionary).to receive(:current!).and_raise(ActiveRecord::ConnectionNotEstablished)
      described_class.new(queued.id).record_failure(ActiveRecord::ConnectionNotEstablished.new)

      expect(QuotaConsumption.find_by(prompt_request: request).status).to eq('refunded')
    end
  end

  # **二重に投入しても、同じ案を 2 度作りません。**
  describe '二重の投入' do
    it '投入済みでなければ進めません' do
      run
      expect { described_class.perform_now(request.id) }.not_to raise_error

      expect(request.reload.prompt_outputs.count).to eq(3)
    end
  end

  describe '失敗の記録' do
    it 'すでに決着していれば触れません' do
      run
      before_status = request.reload.status
      described_class.new(request.id).record_failure(StandardError.new)

      expect(request.reload.status).to eq(before_status)
    end
  end
end
