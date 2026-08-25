# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiError do
  subject(:error) do
    described_class.new(code: 'quota_exhausted', message: '本日の生成枠を使い切りました。',
                        next_action: '次回のリセットをお待ちください。', status: 429)
  end

  it '決まった形の本体を返します' do
    expect(error.to_body).to eq(
      error: {
        code: 'quota_exhausted',
        message: '本日の生成枠を使い切りました。',
        next_action: '次回のリセットをお待ちください。',
        details: {}
      }
    )
  end

  it '状態コードを保持します' do
    expect(error.status).to eq(429)
  end

  it '文言を空にできません' do
    expect do
      described_class.new(code: 'x', message: '', next_action: 'y', status: 400)
    end.to raise_error(ArgumentError, /message/)
  end

  it '次に行う操作を空にできません' do
    expect do
      described_class.new(code: 'x', message: 'y', next_action: '', status: 400)
    end.to raise_error(ArgumentError, /next_action/)
  end

  it '識別子を空にできません' do
    expect do
      described_class.new(code: '', message: 'y', next_action: 'z', status: 400)
    end.to raise_error(ArgumentError, /code/)
  end
end
