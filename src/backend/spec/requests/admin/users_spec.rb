# frozen_string_literal: true

require 'rails_helper'

# 利用者とプラン値の管理（issue #66）と、クォータの手動リセット（issue #67）です。
RSpec.describe '管理画面 : 利用者' do # rubocop:disable RSpec/DescribeClass
  let(:name) { 'admin-for-spec' }
  let(:password) { 'password-for-spec' }
  let(:user) { User.create!(x_user_id: '7777777777', display_name: 'みどり', plan: 'pending') }

  def headers
    { 'HTTP_AUTHORIZATION' =>
        ActionController::HttpAuthentication::Basic.encode_credentials(name, password) }
  end

  # 判定サービスへ実際に問い合わせません。**外へ通信しません。**
  #
  # **組み立ての時点で環境変数を読みます。** 応答だけを差し替えても、
  # 差し替える相手を組み立てる段で落ちます。手元は `.env` に値があるため
  # 通り、値の無い自動検査では通りません（PR #175 の整備で実測されました）。
  # **判定サービスの設定も、ここで差し替えます。**
  # 管理画面が持つ経路の一覧です。**ここに無い経路は作りません。**
  def expected_admin_routes
    ['GET /admin',
     'GET /admin/rule-dictionaries', 'POST /admin/rule-dictionaries',
     'GET /admin/rule-dictionaries/new', 'GET /admin/rule-dictionaries/:id',
     'POST /admin/rule-dictionaries/:id/publish',
     'GET /admin/users', 'GET /admin/users/:id',
     'POST /admin/users/:id/recheck', 'POST /admin/users/:id/reset-quota',
     'GET /admin/metrics']
  end

  # 管理画面が持つ経路です。**すべて数え上げます。**
  def admin_routes
    lines = Rails.application.routes.routes.map do |route|
      "#{route.verb} #{route.path.spec.to_s.sub('(.:format)', '')}"
    end

    lines.select { |line| line.include?('/admin') }
  end

  def gate_keys
    %w[FOLLOWER_GATE_BASE_URL FOLLOWER_GATE_CLIENT_ID FOLLOWER_GATE_CREDENTIAL]
  end

  def stub_decision(plan)
    decision = instance_double(FollowerGateClient::Decision, confirmed: true, plan: plan)
    allow_any_instance_of(FollowerGateClient).to receive(:decide).and_return(decision) # rubocop:disable RSpec/AnyInstance
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with(Admin::Credentials::USER_NAME_KEY, nil).and_return(name)
    allow(ENV).to receive(:fetch).with(Admin::Credentials::PASSWORD_KEY, nil).and_return(password)
    gate_keys.each do |key|
      allow(ENV).to receive(:fetch).with(key).and_return("#{key.downcase}-for-spec")
    end
  end

  describe '認証' do
    it '認証がなければ一覧を返しません' do
      get '/admin/users'

      expect(response).to have_http_status(:unauthorized)
    end

    it '認証がなければ再判定できません' do
      post "/admin/users/#{user.id}/recheck"

      expect(response).to have_http_status(:unauthorized)
    end

    it '認証がなければリセットできません' do
      post "/admin/users/#{user.id}/reset-quota"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe '一覧' do
    it '利用者とプラン値を並べます' do
      user

      get '/admin/users', headers: headers

      expect(response.body).to include('みどり').and include('pending')
    end
  end

  describe '手動再判定' do
    it 'プラン値へ反映します' do
      stub_decision('full')

      post "/admin/users/#{user.id}/recheck", headers: headers

      expect(user.reload.plan).to eq('active')
    end

    it '実施者と日時を記録します' do
      stub_decision('full')

      expect { post "/admin/users/#{user.id}/recheck", headers: headers }
        .to change(AdminAction, :count).by(1)
    end

    it '記録に実施者の名前が残ります' do
      stub_decision('full')

      post "/admin/users/#{user.id}/recheck", headers: headers

      expect(AdminAction.last).to have_attributes(actor: name,
                                                  action: AdminAction::RECHECKED_PLAN,
                                                  user_id: user.id)
    end

    # **クールダウンを必ず通します**（requirements.md 6）。
    it '続けて要求するとクールダウンで断ります' do
      stub_decision('full')
      post "/admin/users/#{user.id}/recheck", headers: headers

      post "/admin/users/#{user.id}/recheck", headers: headers

      expect(flash[:alert]).to be_present
    end

    it 'クールダウン中は記録を増やしません' do
      stub_decision('full')
      post "/admin/users/#{user.id}/recheck", headers: headers

      expect { post "/admin/users/#{user.id}/recheck", headers: headers }
        .not_to change(AdminAction, :count)
    end

    # **プラン値を手で書き換える経路を作りません。**
    # 手で書き換えられると、判定手段と機能側の境目が崩れます。
    it 'プラン値を直に書き換える経路がありません' do
      expect { Rails.application.routes.recognize_path('/admin/users/1', method: :patch) }
        .to raise_error(ActionController::RoutingError)
    end

    # **経路の一覧そのものを固定します**（PR #175 のレビュー・要修正 5 / M8）。
    #
    # 「その 1 本が無い」だけでは、別の書き方の経路（`.../set-plan` など）を
    # 足しても素通りします。**管理画面が持つ経路を、すべて数え上げます。**
    it '管理画面の経路は、決めたものだけです' do
      expect(admin_routes).to match_array(expected_admin_routes)
    end

    # **書き込みの経路が、印の無い要求を通しません**（要修正 5 / M7）。
    #
    # API モードでは `protect_from_forgery` を書いても働かないことがあります。
    # **この PR が足した経路そのもので確かめます。**
    describe '書き込みの守り' do
      before { ActionController::Base.allow_forgery_protection = true }

      after { ActionController::Base.allow_forgery_protection = false }

      it '再判定は、印の無い書き込みを通しません' do
        post "/admin/users/#{user.id}/recheck", headers: headers

        expect(response).not_to have_http_status(:found)
      end

      it 'リセットは、印の無い書き込みを通しません' do
        post "/admin/users/#{user.id}/reset-quota", headers: headers

        expect(response).not_to have_http_status(:found)
      end

      it '印が無いことを理由に止めます' do
        post "/admin/users/#{user.id}/recheck", headers: headers

        expect(response.body).to include('InvalidAuthenticityToken')
      end
    end
  end

  describe 'クォータの手動リセット' do
    let(:active) { User.create!(x_user_id: '8888888888', display_name: 'あお', plan: 'active') }
    let(:project) { Project.create!(user: active, industry: 'saas', style_family: 'photoreal') }

    def consume!
      request = PromptRequest.create!(project: project, target_model: 'midjourney',
                                      inputs: {}, status: 'draft')
      consumption = Quota::Reservation.reserve!(user: active, prompt_request: request)
      request.transition_to!('queued')
      request.transition_to!('generating')
      request.transition_to!('completed')
      Quota::Reservation.settle!(request)
      consumption.reload
    end

    it '確定済みの消費でもリセットできます' do
      consume!

      post "/admin/users/#{active.id}/reset-quota", headers: headers

      expect(QuotaConsumption.find_for(active, Quota::QuotaDay.of).status).to eq('refunded')
    end

    # **リセット後に当日中の生成ができます**（受け入れ条件）。
    it 'リセット後に当日中の生成ができます' do
      consume!
      expect(Quota::Reservation.remaining_for?(active)).to be(false)

      post "/admin/users/#{active.id}/reset-quota", headers: headers

      expect(Quota::Reservation.remaining_for?(active)).to be(true)
    end

    it 'もう一度予約できます' do
      consume!
      post "/admin/users/#{active.id}/reset-quota", headers: headers

      expect { Quota::Reservation.reserve!(user: active) }.not_to raise_error
    end

    # **手動リセットであることを記録へ残します。**
    it '手動リセットの印を残します' do
      consume!

      post "/admin/users/#{active.id}/reset-quota", headers: headers

      expect(QuotaConsumption.find_for(active, Quota::QuotaDay.of).reset_by_admin).to be(true)
    end

    it '実施者と日時を記録します' do
      consume!

      expect { post "/admin/users/#{active.id}/reset-quota", headers: headers }
        .to change(AdminAction, :count).by(1)
    end

    it '記録に実施者とクォータ日が残ります' do
      consume!

      post "/admin/users/#{active.id}/reset-quota", headers: headers

      expect(AdminAction.last).to have_attributes(
        actor: name, action: AdminAction::RESET_QUOTA, user_id: active.id
      )
      expect(AdminAction.last.details).to eq('quota_day' => Quota::QuotaDay.of.to_s)
    end

    it '本日の消費が無ければ、何も変えません' do
      expect { post "/admin/users/#{active.id}/reset-quota", headers: headers }
        .not_to change(AdminAction, :count)
    end

    # **生成中の枠には当てません**（PR #175 のレビュー・要修正 1）。
    #
    # 先に返してしまうと、動いているジョブが決着できず、**成果物は届いて
    # いるのにジョブが失敗のまま残ります。**
    describe '生成が動いている最中' do
      def reserve!
        request = PromptRequest.create!(project: project, target_model: 'midjourney',
                                        inputs: {}, status: 'draft')
        Quota::Reservation.reserve!(user: active, prompt_request: request)
        request.transition_to!('queued')
        request
      end

      it 'リセットを断ります' do
        reserve!

        post "/admin/users/#{active.id}/reset-quota", headers: headers

        expect(QuotaConsumption.find_for(active, Quota::QuotaDay.of).status).to eq('reserved')
      end

      it '理由を伝えます' do
        reserve!

        post "/admin/users/#{active.id}/reset-quota", headers: headers

        expect(flash[:alert]).to eq(I18n.t('admin.users.in_progress'))
      end

      it '記録を増やしません' do
        reserve!

        expect { post "/admin/users/#{active.id}/reset-quota", headers: headers }
          .not_to change(AdminAction, :count)
      end
    end

    it '本日の消費が無ければ、その旨を伝えます' do
      post "/admin/users/#{active.id}/reset-quota", headers: headers

      expect(flash[:alert]).to eq(I18n.t('admin.users.no_quota'))
    end

    # **お知らせが、実際の画面に出ることを確かめます。**
    # 移った先を描くところまで通します（PR #175 の整備で実測された症状です）。
    it 'お知らせが移った先の画面に出ます' do
      consume!
      post "/admin/users/#{active.id}/reset-quota", headers: headers

      # **移った先でも資格情報が要ります。**
      get response.location, headers: headers

      expect(response.body).to include(I18n.t('admin.users.quota_reset'))
    end

    it '移った先の画面が開けます' do
      consume!
      post "/admin/users/#{active.id}/reset-quota", headers: headers

      get response.location, headers: headers

      expect(response).to have_http_status(:ok)
    end
  end

  describe '記録の表示' do
    it '管理の操作の記録を並べます' do
      AdminAction.record!(actor: name, action: AdminAction::RESET_QUOTA, user: user)

      get "/admin/users/#{user.id}", headers: headers

      expect(response.body).to include(name).and include(AdminAction::RESET_QUOTA)
    end

    # **年を含む日時で出します**（issue #177 の提案 13）。
    # 監査の記録ですので、年が無いと後から追えません。
    it '記録の日時に年を出します' do
      AdminAction.record!(actor: name, action: AdminAction::RESET_QUOTA, user: user)

      get "/admin/users/#{user.id}", headers: headers

      expect(response.body).to include("#{AdminAction.last.created_at.year}年")
    end

    it '記録の日時を、監査の書式で出します' do
      AdminAction.record!(actor: name, action: AdminAction::RESET_QUOTA, user: user)

      get "/admin/users/#{user.id}", headers: headers

      expect(response.body)
        .to include(I18n.l(AdminAction.last.created_at, format: :audit_at))
    end
  end
end
