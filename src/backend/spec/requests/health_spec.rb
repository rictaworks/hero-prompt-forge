# frozen_string_literal: true

require 'rails_helper'

# 死活監視の応答を、実際の要求として確かめます（requirements.md 7.3）。
RSpec.describe 'ヘルスチェック' do # rubocop:disable RSpec/DescribeClass
  describe '正常なとき' do
    it '200 を返します' do
      get '/health'

      expect(response).to have_http_status(:ok)
    end

    it '状態を返します' do
      get '/health'

      expect(response.parsed_body['status']).to eq('ok')
    end

    # **認証を求めません。** 求めると、監視の設定に資格情報を置くことになります。
    it '認証を求めません' do
      get '/health'

      expect(response).not_to have_http_status(:unauthorized)
    end

    # **内部の作りを出しません。** 表の名前・接続先・版は、攻める側の手がかりです。
    it '内部の作りを返しません' do
      get '/health'

      expect(response.parsed_body.keys).to contain_exactly('status')
    end
  end

  # **データベースへ到達できることまで含めて答えます。**
  # アプリが起動しているだけでは、利用者から見た稼働を表せません。
  describe 'データベースへ到達できないとき' do
    before do
      allow(ActiveRecord::Base).to receive(:connection)
        .and_raise(ActiveRecord::ConnectionNotEstablished)
    end

    it '503 を返します' do
      get '/health'

      expect(response).to have_http_status(:service_unavailable)
    end

    it '到達できない旨を返します' do
      get '/health'

      expect(response.parsed_body['status']).to eq('unavailable')
    end

    it '内部の作りを返しません' do
      get '/health'

      expect(response.parsed_body.keys).to contain_exactly('status')
    end

    # **握りつぶしません。** 静かに 503 を返すだけでは、原因を追えません。
    it '記録へ残します' do
      allow(Rails.logger).to receive(:error)

      get '/health'

      expect(Rails.logger).to have_received(:error).with(a_string_including('[health]'))
    end
  end

  # **待ち受ける番号は、環境が決めます。**
  # Railway は `PORT` を注入します。アプリはその値で待ち受けます。
  describe '待ち受ける番号' do
    it 'PORT を読みます' do
      config = Rails.root.join('config/puma.rb').read

      expect(config).to include('PORT')
    end
  end
end
