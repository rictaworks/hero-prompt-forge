# frozen_string_literal: true

require 'rails_helper'

# 生成履歴です（issue #59）。
RSpec.describe '生成履歴 API' do # rubocop:disable RSpec/DescribeClass
  let(:user) { User.create!(x_user_id: '4040404040', display_name: 'すず', plan: 'active') }
  let(:other) { User.create!(x_user_id: '5050505050', display_name: 'まひろ', plan: 'active') }
  let(:project) { Project.create!(user: user, industry: 'saas', style_family: 'photoreal') }

  def prompt_request(target_project: project)
    PromptRequest.create!(project: target_project, target_model: 'midjourney')
  end

  def delivered(degraded: false)
    found = prompt_request
    found.transition_to!('queued')
    found.transition_to!('generating')
    PromptOutput.create!(prompt_request: found, variation_no: 1,
                         composition_type: 'subject_led', main_prompt: 'prompt 1',
                         art_direction_note: '{}')
    found.transition_to!(degraded ? 'degraded_completed' : 'completed', degraded: degraded)
    found
  end

  def theirs
    theirs_project = Project.create!(user: other, industry: 'saas', style_family: 'photoreal')
    PromptRequest.create!(project: theirs_project, target_model: 'dalle')
  end

  def listed
    response.parsed_body['prompt_requests']
  end

  it '未認証では 401 を返します' do
    get '/api/v1/prompt_requests'

    expect(response).to have_http_status(:unauthorized)
  end

  describe 'ログインしている場合' do
    before { login_as(user) }

    # **他人の履歴は載りません。**
    it '自分のものだけを返します' do
      mine = prompt_request
      theirs

      get '/api/v1/prompt_requests'

      expect(listed.pluck('id')).to eq([mine.id])
    end

    it '新しいものから並べます' do
      older = prompt_request
      newer = prompt_request

      get '/api/v1/prompt_requests'

      expect(listed.pluck('id')).to eq([newer.id, older.id])
    end

    it 'プロジェクトで絞り込めます' do
      mine = prompt_request
      another = Project.create!(user: user, industry: 'medical', style_family: 'photoreal')
      prompt_request(target_project: another)

      get '/api/v1/prompt_requests', params: { project_id: project.id }

      expect(listed.pluck('id')).to eq([mine.id])
    end

    # **他人のプロジェクトの識別子で絞られても、何も返しません。**
    it '他人のプロジェクトで絞ると空になります' do
      theirs_request = theirs

      get '/api/v1/prompt_requests', params: { project_id: theirs_request.project_id }

      expect(listed).to be_empty
    end

    # **上限に達していても閲覧できます。** 閲覧は生成ではありません。
    it '上限に達していても閲覧できます' do
      mine = prompt_request
      Quota::Reservation.reserve!(user: user)

      get '/api/v1/prompt_requests'

      expect(listed.pluck('id')).to eq([mine.id])
    end

    it '上限に達していても 200 を返します' do
      Quota::Reservation.reserve!(user: user)

      get '/api/v1/prompt_requests'

      expect(response).to have_http_status(:ok)
    end

    # **縮退の印が履歴にも残ります。**
    it '縮退の印を返します' do
      delivered(degraded: true)

      get '/api/v1/prompt_requests'

      expect(listed.first['degraded']).to be(true)
    end

    it '縮退していなければ印は立ちません' do
      delivered

      get '/api/v1/prompt_requests'

      expect(listed.first['degraded']).to be(false)
    end

    # **どのプロジェクトのものかを返します**（PR #167 のレビューより）。
    # 一覧から辿れないと、過去案の再表示ができません。
    it 'プロジェクトの識別子を返します' do
      mine = prompt_request

      get '/api/v1/prompt_requests'

      expect(listed.first['project_id']).to eq(mine.project_id)
    end

    it '案の数を返します' do
      delivered

      get '/api/v1/prompt_requests'

      expect(listed.first['outputs_count']).to eq(1)
    end

    # **一覧に案そのものを載せません。** 取り出しは 1 件ずつ行います。
    it '案そのものは載せません' do
      delivered

      get '/api/v1/prompt_requests'

      expect(listed.first).not_to have_key('outputs')
    end

    it '状態を返します' do
      delivered(degraded: true)

      get '/api/v1/prompt_requests'

      expect(listed.first['status']).to eq('degraded_completed')
    end
  end
end
