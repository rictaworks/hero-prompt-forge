# frozen_string_literal: true

require 'rails_helper'

# プリセットの保存・一覧・呼び出しです（issue #58）。
RSpec.describe 'プリセット API' do # rubocop:disable RSpec/DescribeClass
  let(:user) { User.create!(x_user_id: '2020202020', display_name: 'ふう', plan: 'active') }
  let(:other) { User.create!(x_user_id: '3030303030', display_name: 'こはる', plan: 'active') }

  let(:conditions) do
    { 'industry' => 'saas', 'style_family' => 'photoreal', 'brand_tone' => 'trust' }
  end

  def preset
    @preset ||= Preset.create!(user: user, name: '定番', input_conditions: conditions)
  end

  def theirs
    Preset.create!(user: other, name: 'よその定番', input_conditions: conditions)
  end

  describe '一覧（GET /api/v1/presets）' do
    it '未認証では 401 を返します' do
      get '/api/v1/presets'

      expect(response).to have_http_status(:unauthorized)
    end

    # **他人のプリセットは載りません。**
    it '自分のものだけを返します' do
      preset
      theirs
      login_as(user)

      get '/api/v1/presets'

      expect(response.parsed_body['presets'].pluck('id')).to eq([preset.id])
    end

    it '名前の順に並べます' do
      Preset.create!(user: user, name: 'あさ', input_conditions: conditions)
      preset
      login_as(user)

      get '/api/v1/presets'

      expect(response.parsed_body['presets'].pluck('name')).to eq(%w[あさ 定番])
    end
  end

  describe '呼び出し（GET /api/v1/presets/:id）' do
    before { login_as(user) }

    it '入力条件を返します' do
      get "/api/v1/presets/#{preset.id}"

      expect(response.parsed_body['input_conditions']).to eq(conditions)
    end

    # **他人のプリセットを呼び出せません。**
    it '他人のものでは 404 を返します' do
      get "/api/v1/presets/#{theirs.id}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe '保存（POST /api/v1/presets）' do
    before { login_as(user) }

    it '201 を返します' do
      post '/api/v1/presets',
           params: { preset: { name: '新しい定番', input_conditions: conditions } }, as: :json

      expect(response).to have_http_status(:created)
    end

    it '保存した利用者に結び付けます' do
      post '/api/v1/presets',
           params: { preset: { name: '新しい定番', input_conditions: conditions } }, as: :json

      expect(Preset.find(response.parsed_body['id']).user).to eq(user)
    end

    # **保存できる項目は決まっています。**
    it '決まっていない項目を含むと 400 を返します' do
      post '/api/v1/presets',
           params: { preset: { name: '新しい定番',
                               input_conditions: conditions.merge('unknown' => 'x') } },
           as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it '同じ名前は 400 を返します' do
      preset

      post '/api/v1/presets',
           params: { preset: { name: '定番', input_conditions: conditions } }, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    # **他人と同じ名前は使えます。** 一意なのは利用者ごとです。
    it '他人と同じ名前は保存できます' do
      theirs

      post '/api/v1/presets',
           params: { preset: { name: 'よその定番', input_conditions: conditions } }, as: :json

      expect(response).to have_http_status(:created)
    end
  end

  describe '更新（PATCH /api/v1/presets/:id）' do
    before { login_as(user) }

    it '名前を変えられます' do
      patch "/api/v1/presets/#{preset.id}", params: { preset: { name: '定番2' } }, as: :json

      expect(preset.reload.name).to eq('定番2')
    end

    # **他人のプリセットを操作できません。**
    it '他人のものでは 404 を返します' do
      patch "/api/v1/presets/#{theirs.id}", params: { preset: { name: '書き換え' } }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it '他人のものを書き換えません' do
      target = theirs

      patch "/api/v1/presets/#{target.id}", params: { preset: { name: '書き換え' } }, as: :json

      expect(target.reload.name).to eq('よその定番')
    end
  end
end
