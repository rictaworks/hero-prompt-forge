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
  #
  # **設定を実際に読み込んで確かめます。** 文字が含まれることを見るだけでは、
  # 使われずに残っているだけの記述でも通ります（PR #150 のレビューより）。
  describe '待ち受ける番号' do
    # `config/puma.rb` を実際に読み込み、待ち受ける番号を取り出します。
    #
    # **設定の書きぶりを見ません。実際に評価して、決まった番号を見ます。**
    def port_from_puma(env)
      require 'puma/configuration'
      with_env(env) do
        path = Rails.root.join('config/puma.rb').to_s
        configuration = Puma::Configuration.new({ config_files: [path] })
        configuration.load
        configuration.clamp
        configuration.options[:binds]
      end
    end

    def with_env(env)
      original = ENV.fetch('PORT', nil)
      ENV['PORT'] = env
      yield
    ensure
      ENV['PORT'] = original
    end

    it '環境が指定した番号で待ち受けます' do
      expect(port_from_puma('4567').join(' ')).to include('4567')
    end

    it '指定が無ければ 3000 で待ち受けます' do
      expect(port_from_puma(nil).join(' ')).to include('3000')
    end
  end
end
