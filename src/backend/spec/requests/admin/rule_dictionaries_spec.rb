# frozen_string_literal: true

require 'rails_helper'

# 規則辞書の編集です（requirements.md 4.3、7.2、issue #65）。
RSpec.describe '管理画面 : 規則辞書' do # rubocop:disable RSpec/DescribeClass
  let(:name) { 'admin-for-spec' }
  let(:password) { 'password-for-spec' }

  let!(:published) do
    RuleDictionary.create!(
      version: 'vspec.published',
      anti_ai_rules: InitialRuleDictionary.anti_ai_rules,
      style_spec_rules: InitialRuleDictionary.style_spec_rules,
      industry_defaults: InitialRuleDictionary.industry_defaults
    ).tap { |found| found.publish!(now: Time.zone.parse('2026-01-01 00:00:00 +09:00')) }
  end

  def credentials
    ActionController::HttpAuthentication::Basic.encode_credentials(name, password)
  end

  def headers
    { 'HTTP_AUTHORIZATION' => credentials }
  end

  def content_params(**overrides)
    {
      version: 'vspec.new',
      anti_ai_rules: published.anti_ai_rules.to_json,
      style_spec_rules: published.style_spec_rules.to_json,
      industry_defaults: published.industry_defaults.to_json
    }.merge(overrides)
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with(AuthenticatesAdmin::USER_NAME_KEY, nil).and_return(name)
    allow(ENV).to receive(:fetch).with(AuthenticatesAdmin::PASSWORD_KEY, nil).and_return(password)
  end

  describe '認証' do
    it '認証がなければ一覧を返しません' do
      get '/admin/rule-dictionaries'

      expect(response).to have_http_status(:unauthorized)
    end

    it '認証がなければ版を作れません' do
      post '/admin/rule-dictionaries', params: content_params

      expect(response).to have_http_status(:unauthorized)
    end

    it '認証がなければ公開できません' do
      post "/admin/rule-dictionaries/#{published.id}/publish"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe '一覧' do
    it '版を並べます' do
      get '/admin/rule-dictionaries', headers: headers

      expect(response.body).to include('vspec.published')
    end

    it 'いま使う版が分かります' do
      get '/admin/rule-dictionaries', headers: headers

      expect(response.body).to include(I18n.t('admin.labels.current'))
    end
  end

  describe '新しい版の下書き' do
    # **白紙から書き起こさせません。** 項目の写し忘れで、撮影指示を欠いた版ができます。
    it 'いま使う版の内容を写します' do
      get '/admin/rule-dictionaries/new', headers: headers

      expect(response.body).to include('lens_mm')
    end
  end

  describe '版を切る' do
    it '新しい版を作れます' do
      expect { post '/admin/rule-dictionaries', params: content_params, headers: headers }
        .to change(RuleDictionary, :count).by(1)
    end

    it '作った直後は未公開です' do
      post '/admin/rule-dictionaries', params: content_params, headers: headers

      expect(RuleDictionary.find_by(version: 'vspec.new')).not_to be_published
    end

    # **読めない JSON を受け付けません。** 規則の無い版が公開できてしまいます。
    it '読めない JSON は受け付けません' do
      post '/admin/rule-dictionaries',
           params: content_params(anti_ai_rules: '{ こわれた'), headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it '読めない JSON では版を作りません' do
      expect do
        post '/admin/rule-dictionaries',
             params: content_params(anti_ai_rules: '{ こわれた'), headers: headers
      end.not_to change(RuleDictionary, :count)
    end

    it '連想配列でない JSON も受け付けません' do
      post '/admin/rule-dictionaries',
           params: content_params(industry_defaults: '[1, 2, 3]'), headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it '版の名前が重なれば受け付けません' do
      post '/admin/rule-dictionaries',
           params: content_params(version: published.version), headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe '公開' do
    let(:draft) do
      RuleDictionary.create!(version: 'vspec.draft',
                             anti_ai_rules: published.anti_ai_rules,
                             style_spec_rules: published.style_spec_rules,
                             industry_defaults: published.industry_defaults)
    end

    it '未公開の版を公開できます' do
      post "/admin/rule-dictionaries/#{draft.id}/publish", headers: headers

      expect(draft.reload).to be_published
    end

    # **公開した瞬間から、次の生成に効きます**（requirements.md 7.2）。
    it '公開した版が、次の生成で使われます' do
      post "/admin/rule-dictionaries/#{draft.id}/publish", headers: headers

      expect(RuleDictionary.current.version).to eq('vspec.draft')
    end

    it '実施者と日時を記録します' do
      expect { post "/admin/rule-dictionaries/#{draft.id}/publish", headers: headers }
        .to change(AdminAction, :count).by(1)
    end

    it '記録に実施者の名前が残ります' do
      post "/admin/rule-dictionaries/#{draft.id}/publish", headers: headers

      expect(AdminAction.last.actor).to eq(name)
    end

    # **公開済みの版は書き換えません。**
    it '公開済みの版は、もう一度公開できません' do
      post "/admin/rule-dictionaries/#{published.id}/publish", headers: headers

      expect(response).to have_http_status(:found)
    end

    it '公開済みの版を公開しようとしても、記録を増やしません' do
      expect { post "/admin/rule-dictionaries/#{published.id}/publish", headers: headers }
        .not_to change(AdminAction, :count)
    end
  end

  describe '編集内容が生成に反映されること' do
    # **管理画面から編集した内容が、実際の組み立てへ届くことを確かめます。**
    it '編集した仕様が、組み立てた素材に現れます' do
      rules = published.style_spec_rules.deep_dup
      rules['photoreal']['lens_mm'] = ['a 135mm telephoto lens']
      post '/admin/rule-dictionaries',
           params: content_params(version: 'vspec.edited', style_spec_rules: rules.to_json),
           headers: headers
      created = RuleDictionary.find_by!(version: 'vspec.edited')
      post "/admin/rule-dictionaries/#{created.id}/publish", headers: headers

      input = { industry: 'saas', style_family: 'photoreal' }
      draft = Generation::StyleSpec.new(dictionary: RuleDictionary.current!)
                                   .apply(Generation::Draft.new(input: input))

      expect(draft.main_terms).to include('a 135mm telephoto lens')
    end
  end
end
