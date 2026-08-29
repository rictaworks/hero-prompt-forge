# frozen_string_literal: true

require 'rails_helper'

# 利用状況の集計です（requirements.md 7.1、issue #68）。
RSpec.describe '管理画面 : 利用状況' do # rubocop:disable RSpec/DescribeClass
  let(:name) { 'admin-for-spec' }
  let(:password) { 'password-for-spec' }

  def headers
    { 'HTTP_AUTHORIZATION' =>
        ActionController::HttpAuthentication::Basic.encode_credentials(name, password) }
  end

  def user_with_requests(x_user_id:, display_name:, count:, degraded: false)
    user = User.create!(x_user_id: x_user_id, display_name: display_name, plan: 'active')
    project = Project.create!(user: user, industry: 'medical', style_family: 'photoreal')
    count.times { deliver(project, degraded: degraded) }
    user
  end

  def deliver(project, degraded:)
    request = PromptRequest.create!(project: project, target_model: 'midjourney',
                                    inputs: { 'industry' => 'medical',
                                              'style_family' => 'photoreal' },
                                    status: 'draft')
    request.transition_to!('queued')
    request.transition_to!('generating')
    request.transition_to!(degraded ? 'degraded_completed' : 'completed', degraded: degraded)
    request
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with(Admin::Credentials::USER_NAME_KEY, nil).and_return(name)
    allow(ENV).to receive(:fetch).with(Admin::Credentials::PASSWORD_KEY, nil).and_return(password)
  end

  describe '認証' do
    it '認証がなければ返しません' do
      get '/admin/metrics'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe '表示' do
    it '記録が無くても開けます' do
      get '/admin/metrics', headers: headers

      expect(response).to have_http_status(:ok)
    end

    # **記録していない軸があることを、画面で断ります**（issue #177 の M11）。
    # 断り書きが消えると、出ている数字が測定の軸を覆い尽くしているように
    # 見えます。**記録していないものを、記録した 0 件と読み違えます。**
    it '記録していない軸があることを断ります' do
      get '/admin/metrics', headers: headers

      expect(response.body).to include(I18n.t('admin.metrics.unrecorded'))
    end

    it '業種別の内訳を出します' do
      user_with_requests(x_user_id: '1111111111', display_name: 'あか', count: 2)

      get '/admin/metrics', headers: headers

      expect(response.body).to include('medical')
    end

    # **個人を特定できる形で表示しません**（受け入れ条件）。
    it '利用者の表示名を出しません' do
      user_with_requests(x_user_id: '1111111111', display_name: 'とくべつなおなまえ', count: 2)

      get '/admin/metrics', headers: headers

      expect(response.body).not_to include('とくべつなおなまえ')
    end

    it '利用者の識別子を出しません' do
      user_with_requests(x_user_id: '1234509876', display_name: 'あか', count: 2)

      get '/admin/metrics', headers: headers

      expect(response.body).not_to include('1234509876')
    end

    # **内部の識別子も出しません**（PR #175 のレビュー・要修正 5 / M9）。
    #
    # 「表示名と X のユーザーIDが出ない」だけでは、`users.id` の軸を足しても
    # 素通りします。**誰が何回使ったかを、この画面から読み取れないようにします。**
    it '利用者の内部の識別子を出しません' do
      user = user_with_requests(x_user_id: '1111111111', display_name: 'あか', count: 7)

      get '/admin/metrics', headers: headers

      expect(labelled_numbers(response.body)).not_to include(user.id.to_s)
    end

    it 'プロジェクトの内部の識別子を出しません' do
      user_with_requests(x_user_id: '1111111111', display_name: 'あか', count: 1)
      project = Project.last

      get '/admin/metrics', headers: headers

      expect(labelled_numbers(response.body)).not_to include(project.id.to_s)
    end

    # 表の見出し（`<th>`）に出る値だけを取り出します。
    # **数そのもの（`<td>`）は集計の結果ですので、対象にしません。**
    def labelled_numbers(body)
      body.scan(%r{<th>([^<]*)</th>}).flatten.map(&:strip)
    end
  end

  describe '集計の中身' do
    subject(:summary) { Metrics::UsageSummary.new.call }

    it '生成リクエスト数を数えます' do
      user_with_requests(x_user_id: '1111111111', display_name: 'あか', count: 2)

      expect(summary[:requests][:total]).to eq(2)
    end

    # **差し戻しは生成の要求として数えません。** 枠も使いません。
    it '差し戻しを数えません' do
      user = User.create!(x_user_id: '2222222222', display_name: 'あお', plan: 'active')
      project = Project.create!(user: user, industry: 'saas', style_family: 'photoreal')
      PromptRequest.create!(project: project, target_model: 'dalle', inputs: {}, status: 'draft')
                   .transition_to!('rejected')

      expect(summary[:requests][:total]).to eq(0)
    end

    it '利用者ごとの件数を分布で返します' do
      user_with_requests(x_user_id: '1111111111', display_name: 'あか', count: 3)
      user_with_requests(x_user_id: '2222222222', display_name: 'あお', count: 1)

      expect(summary[:requests][:by_user]).to eq(users: 2, total: 4, max: 3, median: 2.0)
    end

    # **識別子を返しません。** 分布だけを返します。
    it '利用者ごとの内訳に識別子を含みません' do
      user_with_requests(x_user_id: '1111111111', display_name: 'あか', count: 1)

      expect(summary[:requests][:by_user].keys).to contain_exactly(:users, :total, :max, :median)
    end

    it '縮退の比率を出します' do
      user_with_requests(x_user_id: '1111111111', display_name: 'あか', count: 1, degraded: true)
      user_with_requests(x_user_id: '2222222222', display_name: 'あお', count: 3)

      expect(summary[:degraded]).to eq(delivered: 4, degraded: 1, ratio: 25.0)
    end

    it '母数が 0 でも割りません' do
      expect(summary[:degraded][:ratio]).to eq(0.0)
    end

    it '評価メモの記録率を出します' do
      user_with_requests(x_user_id: '1111111111', display_name: 'あか', count: 1)
      request = PromptRequest.last
      output = PromptOutput.create!(prompt_request: request, variation_no: 1,
                                    composition_type: 'subject_led', main_prompt: 'p',
                                    art_direction_note: '{}')
      EvaluationNote.create!(prompt_output: output, rating: 4)

      expect(summary[:evaluation]).to include(outputs: 1, notes: 1, ratio: 100.0)
    end

    it '評価の分布を出します' do
      user_with_requests(x_user_id: '1111111111', display_name: 'あか', count: 1)
      output = PromptOutput.create!(prompt_request: PromptRequest.last, variation_no: 1,
                                    composition_type: 'subject_led', main_prompt: 'p',
                                    art_direction_note: '{}')
      EvaluationNote.create!(prompt_output: output, rating: 5)

      expect(summary[:evaluation][:by_rating]).to eq(5 => 1)
    end

    # **1 件目は再生成ではありません。**
    it '再生成の回数を出します' do
      user_with_requests(x_user_id: '1111111111', display_name: 'あか', count: 3)

      expect(summary[:regeneration]).to include(projects: 1, requests: 3, regenerations: 2)
    end

    it '上限到達と返還の件数を出します' do
      MetricEvent.create!(axis: MetricEvent::QUOTA_EXHAUSTED,
                          occurred_on: Time.zone.today, occurrences: 5)
      MetricEvent.create!(axis: MetricEvent::QUOTA_RECLAIMED,
                          occurred_on: Time.zone.today, occurrences: 2)

      expect(summary[:quota]).to eq(exhausted: 5, reclaimed: 2)
    end

    # **仕様が定める軸だけを扱います。** 定義に無い指標を増やしません。
    it '返す軸は 5 つだけです' do
      expect(summary.keys).to contain_exactly(:requests, :degraded, :evaluation,
                                              :regeneration, :quota)
    end
  end
end
