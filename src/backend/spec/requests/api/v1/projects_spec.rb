# frozen_string_literal: true

require 'rails_helper'

# プロジェクトの作成・一覧・更新です（issue #57）。
RSpec.describe 'プロジェクト API' do # rubocop:disable RSpec/DescribeClass
  let(:user) { User.create!(x_user_id: '8181818181', display_name: 'いつき', plan: 'active') }
  let(:other) { User.create!(x_user_id: '9191919191', display_name: 'なぎ', plan: 'active') }
  let(:project) { Project.create!(user: user, industry: 'saas', style_family: 'photoreal') }

  def theirs
    Project.create!(user: other, industry: 'medical', style_family: 'illustration')
  end

  def attributes(**overrides)
    { name: 'あおぞら歯科', industry: 'medical', style_family: 'photoreal' }.merge(overrides)
  end

  describe '一覧（GET /api/v1/projects）' do
    it '未認証では 401 を返します' do
      get '/api/v1/projects'

      expect(response).to have_http_status(:unauthorized)
    end

    it 'プラン値が有効でなければ 403 を返します' do
      login_as(User.create!(x_user_id: '1010101010', display_name: 'れん', plan: 'pending'))

      get '/api/v1/projects'

      expect(response).to have_http_status(:forbidden)
    end

    # **他人のプロジェクトは載りません。**
    it '自分のものだけを返します' do
      project
      theirs
      login_as(user)

      get '/api/v1/projects'

      expect(response.parsed_body['projects'].pluck('id')).to eq([project.id])
    end

    it '新しいものから並べます' do
      older = project
      newer = Project.create!(user: user, industry: 'saas', style_family: 'abstract')
      login_as(user)

      get '/api/v1/projects'

      expect(response.parsed_body['projects'].pluck('id')).to eq([newer.id, older.id])
    end
  end

  describe '作成（POST /api/v1/projects）' do
    before { login_as(user) }

    it '201 を返します' do
      post '/api/v1/projects', params: { project: attributes }, as: :json

      expect(response).to have_http_status(:created)
    end

    it '作った利用者に結び付けます' do
      post '/api/v1/projects', params: { project: attributes }, as: :json

      expect(Project.find(response.parsed_body['id']).user).to eq(user)
    end

    # **他人のものとして作れません。** 利用者は要求の値で決まりません。
    it '利用者を指定しても、自分のものになります' do
      post '/api/v1/projects',
           params: { project: attributes.merge(user_id: other.id) }, as: :json

      expect(Project.find(response.parsed_body['id']).user).to eq(user)
    end

    it '選べない業種では 400 を返します' do
      post '/api/v1/projects', params: { project: attributes(industry: 'unknown') }, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it '項目と理由を添えます' do
      post '/api/v1/projects', params: { project: attributes(industry: 'unknown') }, as: :json

      expect(response.parsed_body.dig('error', 'details', 'fields'))
        .to include('field' => 'industry', 'reason' => 'inclusion')
    end

    it '入れ物が無ければ 400 を返します' do
      post '/api/v1/projects', params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe '更新（PATCH /api/v1/projects/:id）' do
    before { login_as(user) }

    it '名前を変えられます' do
      patch "/api/v1/projects/#{project.id}",
            params: { project: { name: 'みらい工房' } }, as: :json

      expect(project.reload.name).to eq('みらい工房')
    end

    # **他人のプロジェクトを操作できません。**
    it '他人のものでは 404 を返します' do
      patch "/api/v1/projects/#{theirs.id}",
            params: { project: { name: '書き換え' } }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it '他人のものを書き換えません' do
      target = theirs

      patch "/api/v1/projects/#{target.id}",
            params: { project: { name: '書き換え' } }, as: :json

      expect(target.reload.name).to be_nil
    end

    it '人物の見込みの上書きを保存できます' do
      patch "/api/v1/projects/#{project.id}",
            params: { project: { brand_settings: { people: 'expected' } } }, as: :json

      expect(project.reload.people_expectation).to eq('expected')
    end

    it '選べない上書きでは 400 を返します' do
      patch "/api/v1/projects/#{project.id}",
            params: { project: { brand_settings: { people: 'maybe' } } }, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end
end
