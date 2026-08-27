# frozen_string_literal: true

require 'rails_helper'

# いまログインしている利用者です（issue #70）。
RSpec.describe 'ログイン中の利用者 API' do # rubocop:disable RSpec/DescribeClass
  let(:user) { User.create!(x_user_id: '1212121212', display_name: 'ひかる', plan: 'active') }

  it '未認証では 401 を返します' do
    get '/api/v1/session'

    expect(response).to have_http_status(:unauthorized)
  end

  it '表示名とプラン値を返します' do
    login_as(user)

    get '/api/v1/session'

    expect(response.parsed_body).to eq('display_name' => 'ひかる', 'plan' => 'active')
  end

  # **X のユーザー ID を返しません。** 画面に出す必要がなく、
  # 他の利用者を辿る手がかりになります。
  it 'X のユーザー ID を返しません' do
    login_as(user)

    get '/api/v1/session'

    expect(response.body).not_to include('1212121212')
  end

  # **プラン値の判定を求めません。** `pending` の方も自分の状態を見られます。
  it 'プラン値が有効でなくても返します' do
    login_as(User.create!(x_user_id: '1313131313', display_name: 'なつ', plan: 'pending'))

    get '/api/v1/session'

    expect(response).to have_http_status(:ok)
  end

  it 'プラン値が有効でなければ、その値を返します' do
    login_as(User.create!(x_user_id: '1414141414', display_name: 'なつ', plan: 'pending'))

    get '/api/v1/session'

    expect(response.parsed_body['plan']).to eq('pending')
  end
end
