# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

# 人の操作であることの確かめです（requirements.md 5.2、issue #61）。
RSpec.describe '人の操作の確かめ' do # rubocop:disable RSpec/DescribeClass
  let(:user) { User.create!(x_user_id: '9090909090', display_name: 'ゆい', plan: 'active') }
  let(:project) { Project.create!(user: user, industry: 'saas', style_family: 'photoreal') }
  let(:endpoint) { 'https://www.google.com/recaptcha/api/siteverify' }
  let(:secret) { 'test-secret' } # 開発者向け

  # **公開済みの規則辞書が必要です。** 受付が版を引きます。
  let!(:dictionary) do # rubocop:disable RSpec/LetSetup
    RuleDictionary.create!(
      version: 'vspec.recaptcha',
      anti_ai_rules: InitialRuleDictionary.anti_ai_rules,
      style_spec_rules: InitialRuleDictionary.style_spec_rules,
      industry_defaults: InitialRuleDictionary.industry_defaults
    ).tap(&:publish!)
  end

  def with_key(value)
    stub_env(:fetch, BotProtection::RecaptchaVerifier::SECRET_KEY_VARIABLE, nil, value)
    stub_env(:[], BotProtection::RecaptchaVerifier::SECRET_KEY_VARIABLE, value)
  end

  def stub_env(message, *arguments, value)
    allow(ENV).to receive(message).and_call_original
    allow(ENV).to receive(message).with(*arguments).and_return(value)
  end

  def stub_verification(body:)
    stub_request(:post, endpoint).to_return(status: 200, body: body.to_json,
                                            headers: { 'Content-Type' => 'application/json' })
  end

  def input_fields
    { industry: 'saas', style_family: 'photoreal', target_model: 'midjourney',
      brand_tone: 'trust', copy_space_position: 'left', aspect_ratio: '16:9' }
  end

  def post_request(token: nil)
    headers = token ? { VerifiesHumans::TOKEN_HEADER => token } : {}
    post '/api/v1/prompt_requests',
         params: { project_id: project.id, inputs: input_fields }, as: :json, headers: headers
  end

  before { login_as(user) }

  # **本番では、必ず照合します。**
  describe '本番の場合' do
    before { allow(AppEnvironment).to receive(:production?).and_return(true) }

    it '合図が無ければ 403 を返します' do
      with_key(secret)

      post_request

      expect(response).to have_http_status(:forbidden)
    end

    it '合図が無ければ記録を作りません' do
      with_key(secret)

      expect { post_request }.not_to change(PromptRequest, :count)
    end

    it '合図が無ければ枠を使いません' do
      with_key(secret)

      expect { post_request }.not_to change(QuotaConsumption, :count)
    end

    it '通れば受け付けます' do
      with_key(secret)
      stub_verification(body: { success: true, score: 0.9, action: 'generate_prompt' })

      post_request(token: 'token-value') # 開発者向け

      expect(response).to have_http_status(:created)
    end

    it '得点が低ければ 403 を返します' do
      with_key(secret)
      stub_verification(body: { success: true, score: 0.1, action: 'generate_prompt' })

      post_request(token: 'token-value') # 開発者向け

      expect(response).to have_http_status(:forbidden)
    end

    # **通らなかった理由を返しません。** 通り抜け方を探る手がかりになります。
    it '通らなかった理由を返しません' do
      with_key(secret)
      stub_verification(body: { success: true, score: 0.1, action: 'generate_prompt' })

      post_request(token: 'token-value') # 開発者向け

      expect(response.parsed_body.dig('error', 'details')).to be_empty
    end

    it '照合そのものができなければ 503 を返します' do
      with_key(secret)
      stub_request(:post, endpoint).to_timeout

      post_request(token: 'token-value') # 開発者向け

      expect(response).to have_http_status(:service_unavailable)
    end

    # **鍵の入れ忘れで、Bot 対策が黙って無効になる状態を作りません。**
    it '秘密鍵が無ければ、その場で失敗させます' do
      with_key(nil)

      expect { post_request(token: 'token-value') } # 開発者向け
        .to raise_error(VerifiesHumans::MissingConfigurationError)
    end
  end

  # **分かれ方は、環境だけで決まります。**
  #
  # 要求側の値（本文・見出し・クッキー）で切り替わってはなりません。
  # **この負のテストが無いと、抜け道が入っても誰も気づけません**
  # （PR #168 のレビューで、抜け道を入れても 37 例すべてが緑のままでした）。
  describe '要求側の値で飛ばせないこと' do
    before do
      allow(AppEnvironment).to receive(:production?).and_return(true)
      with_key(secret)
    end

    it '本文の項目では飛ばせません' do
      post '/api/v1/prompt_requests',
           params: { project_id: project.id, inputs: input_fields,
                     skip_recaptcha: true, recaptcha: 'ok' }, # 開発者向け
           as: :json

      expect(response).to have_http_status(:forbidden)
    end

    [{ 'X-Skip-Recaptcha' => 'true' },
     { 'X-App-Env' => 'development' },
     { 'APP_ENV' => 'development' }].each do |headers|
      it "見出し #{headers.keys.first} では飛ばせません" do
        post '/api/v1/prompt_requests',
             params: { project_id: project.id, inputs: input_fields },
             as: :json, headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    it 'クッキーでは飛ばせません' do
      cookies[:skip_recaptcha] = 'true' # 開発者向け

      post_request

      expect(response).to have_http_status(:forbidden)
    end
  end

  # **開発とテストでは、鍵が設定されているときだけ照合します。**
  describe '開発の場合' do
    before { allow(AppEnvironment).to receive(:production?).and_return(false) }

    it '鍵が無ければ、合図なしでも受け付けます' do
      with_key(nil)

      post_request

      expect(response).to have_http_status(:created)
    end

    it '鍵が無ければ、照合へ行きません' do
      with_key(nil)

      post_request

      expect(a_request(:post, endpoint)).not_to have_been_made
    end

    it '鍵があれば照合します' do
      with_key(secret)
      stub_verification(body: { success: true, score: 0.9, action: 'generate_prompt' })

      post_request(token: 'token-value') # 開発者向け

      expect(a_request(:post, endpoint)).to have_been_made
    end

    it '鍵があれば、合図が無いと 403 を返します' do
      with_key(secret)

      post_request

      expect(response).to have_http_status(:forbidden)
    end
  end

  # **閲覧は守りません。** 上限に達した方が履歴すら見られなくなります。
  describe '閲覧の経路' do
    before { allow(AppEnvironment).to receive(:production?).and_return(true) }

    it '合図が無くても履歴を返します' do
      with_key(secret)

      get '/api/v1/prompt_requests'

      expect(response).to have_http_status(:ok)
    end

    it '合図が無くても取り出せます' do
      with_key(secret)
      found = PromptRequest.create!(project: project, target_model: 'midjourney')

      get "/api/v1/prompt_requests/#{found.id}"

      expect(response).to have_http_status(:ok)
    end
  end
end
