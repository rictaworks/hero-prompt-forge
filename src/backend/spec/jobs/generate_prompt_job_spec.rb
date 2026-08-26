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

  # **何度呼んでも、投入済みの状態を 1 つ作るだけです。**
  def queued
    dictionary
    Quota::Reservation.reserve!(user: user, prompt_request: request)
    request.transition_to!('queued') if request.status == 'draft'
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

    # **投入し直しから打ち切りまでを、実際に最後まで走らせます。**
    #
    # 直に `record_failure` を呼ぶだけでは、**投入し直しが仕事をやり直して
    # いるかどうかを確かめられません**（PR #165 のレビューより）。
    describe '最後まで走らせた場合' do
      include ActiveJob::TestHelper

      # 繰り返せば通ることがある誤りを、毎回起こします。
      def always_failing
        allow(RuleDictionary).to receive(:current!)
          .and_raise(ActiveRecord::ConnectionNotEstablished)
      end

      def run_to_the_end
        always_failing
        target = queued
        perform_enqueued_jobs { described_class.perform_later(target.id) }
        request.reload
      end

      # **投入し直しが、仕事をやり直します。**
      it '上限の回数だけ組み立てを試みます' do
        run_to_the_end

        expect(RuleDictionary).to have_received(:current!).exactly(described_class::MAX_ATTEMPTS)
      end

      it '失敗として記録します' do
        run_to_the_end

        expect(request.reload.status).to eq('failed')
      end

      it 'クォータを返します' do
        run_to_the_end

        expect(QuotaConsumption.find_by(prompt_request: request).status).to eq('refunded')
      end

      it '理由の種別を残します' do
        run_to_the_end

        expect(request.reload.rejection_reason)
          .to eq('ActiveRecord::ConnectionNotEstablished')
      end

      it '案を残しません' do
        run_to_the_end

        expect(request.reload.prompt_outputs).to be_empty
      end

      # **記録は一度だけです**（PR #165 の 2 回目のレビューより）。
      # `retry_on` の塊と `after_discard` が重なると、2 度走ります。
      it '失敗の記録は一度だけ走ります' do
        allow(Trace).to receive(:step).and_call_original

        run_to_the_end

        expect(Trace).to have_received(:step)
          .with('jobs.generate_prompt_failed', hash_including(:prompt_request)).once
      end

      # **2 回目で通れば、成果物を提供します。**
      it '途中で通れば、やり直しが実を結びます' do
        attempts = 0
        allow(RuleDictionary).to receive(:current!).and_wrap_original do |call, **options|
          attempts += 1
          raise ActiveRecord::ConnectionNotEstablished if attempts == 1

          call.call(**options)
        end
        target = queued
        perform_enqueued_jobs { described_class.perform_later(target.id) }

        expect(request.reload.prompt_outputs.count).to eq(3)
      end
    end

    # **繰り返しても通らない誤りは、繰り返しません。**
    describe '規則辞書が無い場合' do
      it '繰り返さずに失敗として記録します' do
        target = queued
        allow(RuleDictionary).to receive(:current!)
          .and_raise(RuleDictionary::MissingCurrentError)
        described_class.perform_now(target.id)

        expect(request.reload.status).to eq('failed')
      end

      it '投入し直しません' do
        target = queued
        allow(RuleDictionary).to receive(:current!)
          .and_raise(RuleDictionary::MissingCurrentError)

        expect { described_class.perform_now(target.id) }
          .not_to have_enqueued_job(described_class)
      end

      it 'クォータを返します' do
        target = queued
        allow(RuleDictionary).to receive(:current!)
          .and_raise(RuleDictionary::MissingCurrentError)
        described_class.perform_now(target.id)

        expect(QuotaConsumption.find_by(prompt_request: request).status).to eq('refunded')
      end
    end

    # **想定していない誤りは、記録してから外へ出します。** 握りつぶしません。
    describe '想定していない誤り' do
      before do
        allow(RuleDictionary).to receive(:current!).and_raise(NoMethodError, 'typo') # 開発者向け
      end

      it '外へ出します' do
        target = queued

        expect { described_class.perform_now(target.id) }.to raise_error(NoMethodError)
      end

      it '失敗として記録します' do
        target = queued
        begin
          described_class.perform_now(target.id)
        rescue NoMethodError
          nil
        end

        expect(request.reload.status).to eq('failed')
      end

      it '生成中のまま取り残しません' do
        target = queued
        begin
          described_class.perform_now(target.id)
        rescue NoMethodError
          nil
        end

        expect(QuotaConsumption.find_by(prompt_request: request).status).to eq('refunded')
      end
    end
  end

  # **二重に投入しても、同じ案を 2 度作りません。**
  describe '二重の投入' do
    it '投入済みでなければ進めません' do
      run
      expect { described_class.perform_now(request.id) }.not_to raise_error

      expect(request.reload.prompt_outputs.count).to eq(3)
    end

    # **出来上がった生成リクエストを「生成中」へ巻き戻しません。**
    #
    # 2 つ目の働き手が `queued` のうちに行を読み、1 つ目が終わったあとで
    # 走り出す場合です。**手元の古い値ではなく、錠をかけて読み直した値で
    # 判定します**（PR #165 のレビューで実測されました）。
    it '古い値を持った働き手が、状態を巻き戻しません' do
      stale = PromptRequest.find(queued.id)
      run

      described_class.perform_now(stale.id)

      expect(request.reload.status).to eq('degraded_completed')
    end

    it '案を増やしません' do
      stale = PromptRequest.find(queued.id)
      run

      described_class.perform_now(stale.id)

      expect(request.reload.prompt_outputs.count).to eq(3)
    end
  end

  # **働き手が落ちて置き去りになった行を、拾い直します**
  # （PR #165 の 2 回目のレビューより）。
  describe '働き手が落ちた場合' do
    # 投入し直しではない、新しい投入です。**`executions` は 1 です。**
    def fresh_run(target)
      described_class.perform_now(target.id)
      request.reload
    end

    def abandoned(elapsed)
      target = queued
      target.transition_to!('generating')
      target.update_column(:updated_at, elapsed.ago) # rubocop:disable Rails/SkipsModelValidations
      target
    end

    it '置き去りの行を拾い直します' do
      fresh_run(abandoned(described_class::STALE_AFTER + 1.minute))

      expect(request.reload.prompt_outputs.count).to eq(3)
    end

    it 'クォータを決着させます' do
      fresh_run(abandoned(described_class::STALE_AFTER + 1.minute))

      expect(QuotaConsumption.find_by(prompt_request: request).status).to eq('confirmed')
    end

    # **まだ走っているかもしれない行へ、横入りしません。**
    it '走り出したばかりの行へは横入りしません' do
      fresh_run(abandoned(1.minute))

      expect(request.reload.prompt_outputs).to be_empty
    end

    it '走り出したばかりの行の状態を変えません' do
      fresh_run(abandoned(1.minute))

      expect(request.reload.status).to eq('generating')
    end
  end

  # **確定だけが残った場合も、投入し直しで拾い直します。**
  describe 'クォータの確定が外れた場合' do
    def deliver_without_settlement
      allow(Quota::Reservation).to receive(:settle!)
        .and_raise(ActiveRecord::ConnectionNotEstablished)
      begin
        described_class.perform_now(queued.id)
      rescue ActiveRecord::ConnectionNotEstablished
        nil
      end
      RSpec::Mocks.space.proxy_for(Quota::Reservation).reset
      request.reload
    end

    it '成果物は残ります' do
      deliver_without_settlement

      expect(request.prompt_outputs.count).to eq(3)
    end

    it '枠は予約のまま残ります' do
      deliver_without_settlement

      expect(QuotaConsumption.find_by(prompt_request: request).status).to eq('reserved')
    end

    # **投入し直しが、決着だけを行います。**
    it '投入し直しで確定します' do
      deliver_without_settlement

      described_class.perform_now(request.id)

      expect(QuotaConsumption.find_by(prompt_request: request).status).to eq('confirmed')
    end

    it '案を作り直しません' do
      deliver_without_settlement

      described_class.perform_now(request.id)

      expect(request.reload.prompt_outputs.count).to eq(3)
    end
  end

  # **返還だけが残った場合も、投入し直しで拾い直します**
  # （PR #165 の 2 回目のレビューより）。**確定の場合と対称にします。**
  describe 'クォータの返還が外れた場合' do
    def failed_without_settlement
      target = queued
      allow(Quota::Reservation).to receive(:settle!)
        .and_raise(ActiveRecord::ConnectionNotEstablished)
      begin
        described_class.new(target.id).record_failure(StandardError.new)
      rescue ActiveRecord::ConnectionNotEstablished
        nil
      end
      RSpec::Mocks.space.proxy_for(Quota::Reservation).reset
      request.reload
    end

    it '失敗として記録されたままです' do
      failed_without_settlement

      expect(request.status).to eq('failed')
    end

    it '枠は予約のまま残ります' do
      failed_without_settlement

      expect(QuotaConsumption.find_by(prompt_request: request).status).to eq('reserved')
    end

    it '投入し直しで返還します' do
      failed_without_settlement

      described_class.perform_now(request.id)

      expect(QuotaConsumption.find_by(prompt_request: request).status).to eq('refunded')
    end

    it '案を作りません' do
      failed_without_settlement

      described_class.perform_now(request.id)

      expect(request.reload.prompt_outputs).to be_empty
    end
  end

  # **保存した形を、そのまま読み戻せます。**
  describe '保存の形' do
    it 'ノートを組み立て直せます' do
      run

      expect { JSON.parse(request.prompt_outputs.first.art_direction_note) }.not_to raise_error
    end

    it '推奨パラメータを連想配列で残します' do
      run

      expect(request.prompt_outputs.first.parameters).to be_a(Hash)
    end
  end

  describe '失敗の記録' do
    it 'すでに決着していれば触れません' do
      run
      before_status = request.reload.status
      described_class.new(request.id).record_failure(StandardError.new)

      expect(request.reload.status).to eq(before_status)
    end

    # **記録は一度だけです。**
    it '二度目の記録で状態を壊しません' do
      target = queued
      job = described_class.new(target.id)
      job.record_failure(StandardError.new)
      job.record_failure(StandardError.new)

      expect(request.reload.status).to eq('failed')
    end
  end
end
