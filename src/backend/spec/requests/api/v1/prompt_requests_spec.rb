# frozen_string_literal: true

require 'rails_helper'

# 生成リクエストの受付と、結果の取り出しです（issue #55、#56）。
RSpec.describe '生成リクエスト API' do # rubocop:disable RSpec/DescribeClass
  let(:user) { User.create!(x_user_id: '3131313131', display_name: 'あかね', plan: 'active') }
  let(:project) { Project.create!(user: user, industry: 'saas', style_family: 'photoreal') }

  # **十分に前の時点で公開します。** 時計を戻す例（クォータ日の境界の確かめ）で、
  # 公開より前の時点になると版が引けなくなります。
  let(:published_at) { Time.zone.parse('2026-01-01 00:00:00 +09:00') }

  let!(:dictionary) do
    RuleDictionary.create!(
      version: 'vspec.api',
      anti_ai_rules: InitialRuleDictionary.anti_ai_rules,
      style_spec_rules: InitialRuleDictionary.style_spec_rules,
      industry_defaults: InitialRuleDictionary.industry_defaults
    ).tap { |found| found.publish!(now: published_at) }
  end

  # **`raw` という名前を使いません。** 画面の文字を安全と印づける仕組みと同じ名前です。
  def input_fields(**overrides)
    { industry: 'saas', style_family: 'photoreal', target_model: 'midjourney',
      brand_tone: 'trust', copy_space_position: 'left',
      aspect_ratio: '16:9' }.merge(overrides)
  end

  def post_request(project_id: project.id, **overrides)
    post '/api/v1/prompt_requests',
         params: { project_id: project_id, inputs: input_fields(**overrides) },
         as: :json
  end

  def error_body
    response.parsed_body['error']
  end

  describe '受付（POST /api/v1/prompt_requests）' do
    describe '認証と権限' do
      it '未認証では 401 を返します' do
        post_request

        expect(response).to have_http_status(:unauthorized)
      end

      it 'プラン値が有効でなければ 403 を返します' do
        login_as(User.create!(x_user_id: '4141414141', display_name: 'そら', plan: 'pending'))

        post_request

        expect(response).to have_http_status(:forbidden)
      end

      # **他人の資源へは 403 ではなく 404 を返します。** 存在を知らせません。
      it '他人のプロジェクトでは 404 を返します' do
        other = User.create!(x_user_id: '5151515151', display_name: 'かえで', plan: 'active')
        theirs = Project.create!(user: other, industry: 'saas', style_family: 'photoreal')
        login_as(user)

        post_request(project_id: theirs.id)

        expect(response).to have_http_status(:not_found)
      end
    end

    describe '受け付けられる場合' do
      before { login_as(user) }

      it '201 を返します' do
        post_request

        expect(response).to have_http_status(:created)
      end

      it '識別子と状態を返します' do
        post_request

        expect(response.parsed_body).to include('id' => be_present, 'status' => 'queued')
      end

      it 'ジョブを投入します' do
        expect { post_request }
          .to have_enqueued_job(GeneratePromptJob)
      end

      it '枠を 1 つ予約します' do
        post_request

        expect(QuotaConsumption.where(user: user, status: 'reserved').count).to eq(1)
      end

      # **保存するのは正規化した入力です。** 受け取ったままの値を残しません。
      it '正規化した入力を保存します' do
        post '/api/v1/prompt_requests',
             params: { project_id: project.id,
                       inputs: input_fields.merge(unknown_field: 'x') },
             as: :json

        expect(PromptRequest.last.inputs.keys).not_to include('unknown_field')
      end
    end

    # **必須の項目が欠けても、形が違っても、契約の形で返します**
    # （PR #166 のレビューより）。受け止めないと Rails の既定の応答になり、
    # **画面が利用者へ見せる文言を作れません。**
    describe 'プロジェクトの識別子が正しくない場合' do
      before { login_as(user) }

      def post_without_project(value = nil)
        params = { inputs: input_fields }
        params[:project_id] = value unless value.nil?
        post '/api/v1/prompt_requests', params: params, as: :json
      end

      # 欠けている場合と、形が違う場合（配列・連想配列）です。
      [nil, [1, 1], { 'a' => 1 }].each do |value|
        it "識別子が #{value.inspect} なら 400 を返します" do
          post_without_project(value)

          expect(response).to have_http_status(:bad_request)
        end

        # **契約の形です。** `code` ・ `message` ・ `next_action` を備えます。
        it "識別子が #{value.inspect} でも契約の形で返します" do
          post_without_project(value)

          expect(error_body.keys).to contain_exactly('code', 'message', 'next_action', 'details')
        end

        it "識別子が #{value.inspect} でも利用者へ見せる文言を返します" do
          post_without_project(value)

          expect([error_body['message'], error_body['next_action']]).to all(be_present)
        end

        it "識別子が #{value.inspect} なら項目名を添えます" do
          post_without_project(value)

          expect(error_body.dig('details', 'fields'))
            .to include('field' => 'project_id', 'reason' => 'missing')
        end

        it "識別子が #{value.inspect} なら記録を作りません" do
          expect { post_without_project(value) }.not_to change(PromptRequest, :count)
        end

        it "識別子が #{value.inspect} なら枠を使いません" do
          expect { post_without_project(value) }.not_to change(QuotaConsumption, :count)
        end
      end
    end

    describe '入力に誤りがある場合' do
      before { login_as(user) }

      it '400 を返します' do
        post_request(industry: 'unknown_industry')

        expect(response).to have_http_status(:bad_request)
      end

      it '項目と理由を返します' do
        post_request(industry: 'unknown_industry')

        expect(error_body.dig('details', 'fields'))
          .to include('field' => 'industry', 'reason' => 'unknown_value')
      end

      it '記録を作りません' do
        expect { post_request(industry: 'unknown_industry') }
          .not_to change(PromptRequest, :count)
      end

      it '枠を使いません' do
        expect { post_request(industry: 'unknown_industry') }
          .not_to change(QuotaConsumption, :count)
      end

      # **プラン値が有効でない場合の拒否は、入力を読む前です。**
      it 'プラン値の判定が入力の検証より先です' do
        login_as(User.create!(x_user_id: '6161616161', display_name: 'ひなた', plan: 'pending'))

        post_request(industry: 'unknown_industry')

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe '禁止入力の場合' do
      before { login_as(user) }

      let(:forbidden_summary) { '大谷翔平さんに登場していただくヒーローイメージです。' }

      def post_forbidden
        post_request(service_summary: forbidden_summary)
      end

      it '422 を返します' do
        post_forbidden

        expect(response).to have_http_status(:unprocessable_content)
      end

      # **クォータを消費しません**（requirements.md 4.1 の 1）。
      it '枠を使いません' do
        expect { post_forbidden }.not_to change(QuotaConsumption, :count)
      end

      it '記録を差し戻しの状態で残します' do
        post_forbidden

        expect(PromptRequest.last.status).to eq('rejected')
      end

      it '理由の種別を返します' do
        post_forbidden

        expect(error_body.dig('details', 'reasons').pluck('kind'))
          .to include('real_person')
      end

      it '直し方の鍵を返します' do
        post_forbidden

        expect(error_body.dig('details', 'reasons').first).to have_key('suggestion_key')
      end

      it '次に行う操作を返します' do
        post_forbidden

        expect(error_body['next_action']).to be_present
      end

      # **記録には見つかった語を残しません。** 差し戻しの記録は保管が長くなります。
      it '見つかった語を記録へ残しません' do
        post_forbidden

        expect(PromptRequest.last.rejection_reason).not_to include('大谷')
      end

      # **原文そのものも残しません**（PR #166 のレビューより）。
      # 理由から語を落としても、原文が別の列に残っていては意味がありません。
      it '自由に書いた文章を記録へ残しません' do
        post_forbidden

        expect(PromptRequest.last.inputs).not_to have_key('service_summary')
      end

      it '記録の中身に見つかった語が残りません' do
        post_forbidden

        expect(PromptRequest.last.inputs.to_json).not_to include('大谷')
      end

      # **選択肢の値は残します。** 入力し直していただくときの手がかりです。
      it '選んだ値は残します' do
        post_forbidden

        expect(PromptRequest.last.inputs).to include('industry' => 'saas')
      end

      it 'ジョブを投入しません' do
        expect { post_forbidden }.not_to have_enqueued_job(GeneratePromptJob)
      end
    end

    # **返還済みの枠がある日に禁止入力を送っても、枠を取り直しません**
    # （PR #166 のレビューより）。取り直しは行の更新ですので、**件数では
    # 捉えられません。状態で確かめます。**
    describe '返還済みの枠がある日の禁止入力' do
      before { login_as(user) }

      def refunded_slot
        consumption = Quota::Reservation.reserve!(user: user)
        consumption.transition_to!('refunded')
        consumption
      end

      it '枠は返還済みのままです' do
        slot = refunded_slot

        post_request(service_summary: '大谷翔平さんに登場していただくヒーローイメージです。')

        expect(slot.reload.status).to eq('refunded')
      end

      it '422 を返します' do
        refunded_slot

        post_request(service_summary: '大谷翔平さんに登場していただくヒーローイメージです。')

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    # **クォータ日の境界で、次回のリセット時刻がずれません**（requirements.md 4.4）。
    #
    # **日付まで固定します。** 時だけを見ると、「当日の 03:00（すでに過ぎた
    # 時刻）」を返す退行を捉えられません（PR #166 のレビューより）。
    describe 'クォータ日の境界' do
      include ActiveSupport::Testing::TimeHelpers

      before { login_as(user) }

      # その時点で枠を使い切らせてから、もう一度送ります。
      def reset_at_at(moment)
        travel_to(Time.zone.parse(moment)) do
          Quota::Reservation.reserve!(user: user)
          post_request
          error_body.dig('details', 'reset_at')
        end
      end

      it '03:00 の前は、その日の 03:00 を返します' do
        expect(reset_at_at('2026-08-27 02:59:59 +09:00')).to eq('2026-08-27T03:00:00+09:00')
      end

      it '03:00 からは、翌日の 03:00 を返します' do
        expect(reset_at_at('2026-08-27 03:00:00 +09:00')).to eq('2026-08-28T03:00:00+09:00')
      end
    end

    describe '本日の枠を使い切っている場合' do
      before do
        login_as(user)
        Quota::Reservation.reserve!(user: user)
      end

      it '429 を返します' do
        post_request

        expect(response).to have_http_status(:too_many_requests)
      end

      it '次回のリセット時刻を添えます' do
        post_request

        expect(error_body.dig('details', 'reset_at')).to be_present
      end

      # **JST 03:00 です**（requirements.md 4.4）。
      it '次回のリセットは JST 03:00 です' do
        post_request

        expect(Time.zone.parse(error_body.dig('details', 'reset_at'))
                   .in_time_zone('Asia/Tokyo').hour)
          .to eq(3)
      end

      it '次に行う操作に時刻を書きます' do
        post_request

        expect(error_body['next_action']).to match(/\d+月\d+日/)
      end

      it '曖昧な文言にしません' do
        post_request

        expect(error_body['message']).to eq('本日の生成枠を使い切りました。')
      end

      it 'ジョブを投入しません' do
        expect { post_request }.not_to have_enqueued_job(GeneratePromptJob)
      end
    end
  end

  describe '結果の取り出し（GET /api/v1/prompt_requests/:id）' do
    let(:prompt_request) do
      PromptRequest.create!(project: project, target_model: 'midjourney',
                            inputs: input_fields.transform_keys(&:to_s))
    end

    def get_request(id: prompt_request.id)
      get "/api/v1/prompt_requests/#{id}"
    end

    it '未認証では 401 を返します' do
      get_request

      expect(response).to have_http_status(:unauthorized)
    end

    # **他人のリクエストを参照できません。**
    it '他人のリクエストでは 404 を返します' do
      other = User.create!(x_user_id: '7171717171', display_name: 'つばき', plan: 'active')
      theirs = Project.create!(user: other, industry: 'saas', style_family: 'photoreal')
      theirs_request = PromptRequest.create!(project: theirs, target_model: 'midjourney')
      login_as(user)

      get_request(id: theirs_request.id)

      expect(response).to have_http_status(:not_found)
    end

    it '無い識別子では 404 を返します' do
      login_as(user)

      get_request(id: 0)

      expect(response).to have_http_status(:not_found)
    end

    describe '状態' do
      before { login_as(user) }

      # **requirements.md 12.1 の名前をそのまま返します。**
      it '状態遷移図の名前をそのまま返します' do
        get_request

        expect(response.parsed_body['status']).to eq('draft')
      end

      it '途中の状態では案を返しません' do
        prompt_request.transition_to!('queued')

        get_request

        expect(response.parsed_body).not_to have_key('outputs')
      end
    end

    describe '成果物を提供できた場合' do
      before do
        login_as(user)
        deliver
      end

      def deliver(degraded: false)
        prompt_request.transition_to!('queued')
        prompt_request.transition_to!('generating')
        PromptOutput::VARIATION_COUNT.times { |index| store(index + 1) }
        prompt_request.transition_to!(degraded ? 'degraded_completed' : 'completed',
                                      degraded: degraded, dictionary_version: dictionary.version)
      end

      def store(number)
        PromptOutput.create!(prompt_request: prompt_request, variation_no: number,
                             composition_type: PromptOutput::COMPOSITION_TYPES[number - 1],
                             main_prompt: "prompt #{number}",
                             negative_prompt: 'plastic skin',
                             parameters: { 'aspect_ratio' => '16:9' },
                             art_direction_note: { 'checkpoints' => [] }.to_json)
      end

      it '3 案を返します' do
        get_request

        expect(response.parsed_body['outputs'].size).to eq(3)
      end

      it '案を番号の順で返します' do
        get_request

        expect(response.parsed_body['outputs'].pluck('variation_no'))
          .to eq([1, 2, 3])
      end

      it 'ノートを組み立て直せる形で返します' do
        get_request

        expect(response.parsed_body['outputs'].first['art_direction_note'])
          .to eq('checkpoints' => [])
      end

      it '適用した規則辞書の版を返します' do
        get_request

        expect(response.parsed_body['dictionary_version']).to eq(dictionary.version)
      end
    end

    describe '縮退で生成された場合' do
      before { login_as(user) }

      def deliver_degraded
        prompt_request.transition_to!('queued')
        prompt_request.transition_to!('generating')
        PromptOutput.create!(prompt_request: prompt_request, variation_no: 1,
                             composition_type: 'subject_led', main_prompt: 'prompt 1',
                             art_direction_note: '{}')
        prompt_request.transition_to!('degraded_completed', degraded: true)
      end

      # **縮退で生成された案に印が含まれます**（requirements.md 4.2）。
      it 'リクエストに印が付きます' do
        deliver_degraded

        get_request

        expect(response.parsed_body['degraded']).to be(true)
      end

      it '案ごとにも印が付きます' do
        deliver_degraded

        get_request

        expect(response.parsed_body['outputs'].pluck('degraded'))
          .to all(be(true))
      end
    end

    describe '差し戻した場合' do
      before { login_as(user) }

      it '理由を文言で返します' do
        prompt_request.transition_to!('rejected', rejection_reason: 'real_person')
        login_as(user)

        get_request

        expect(response.parsed_body.dig('failure', 'message')).to be_present
      end

      # **記録の中身をそのまま返しません。** 開発者向けの種別です。
      it '記録の中身をそのまま返しません' do
        prompt_request.transition_to!('rejected', rejection_reason: 'real_person')

        get_request

        expect(response.parsed_body['failure'].values).not_to include('real_person')
      end
    end

    describe '失敗した場合' do
      before { login_as(user) }

      it '次に行う操作を返します' do
        prompt_request.transition_to!('queued')
        prompt_request.transition_to!('generating')
        prompt_request.transition_to!('failed', rejection_reason: 'StandardError')

        get_request

        expect(response.parsed_body.dig('failure', 'next_action')).to be_present
      end
    end
  end
end
