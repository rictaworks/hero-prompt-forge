# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Session do
  let(:user) { User.create!(x_user_id: '1234567890', display_name: 'あお') }
  let(:now) { Time.zone.parse('2026-08-25T10:00:00+09:00') }

  describe '.issue' do
    it 'ログイン状態と識別子を返します' do
      session, token = described_class.issue(user: user, now: now)

      expect([session.persisted?, token.present?]).to eq([true, true])
    end

    it '識別子そのものを保存しません' do
      _session, token = described_class.issue(user: user, now: now)

      expect(described_class.pluck(:token_digest)).not_to include(token)
    end

    it '識別子はハッシュにして保存します' do
      session, token = described_class.issue(user: user, now: now)

      expect(session.token_digest).to eq(described_class.digest(token))
    end

    it '毎回異なる識別子を作ります' do
      _s1, token1 = described_class.issue(user: user, now: now)
      _s2, token2 = described_class.issue(user: user, now: now)

      expect(token1).not_to eq(token2)
    end

    it '失効する時刻を設定します' do
      session, _token = described_class.issue(user: user, now: now)

      expect(session.expires_at).to eq(now + described_class::LIFETIME)
    end

    it '推測しにくい長さの識別子を作ります' do
      _session, token = described_class.issue(user: user, now: now)

      expect(token.length).to be >= 40
    end
  end

  describe '.find_alive' do
    it '識別子からログイン状態を見つけます' do
      session, token = described_class.issue(user: user, now: now)

      expect(described_class.find_alive(token, now: now)).to eq(session)
    end

    it '失効していれば見つけません' do
      _session, token = described_class.issue(user: user, now: now)

      expect(described_class.find_alive(token, now: now + described_class::LIFETIME + 1.second))
        .to be_nil
    end

    it '取り消されていれば見つけません' do
      session, token = described_class.issue(user: user, now: now)
      session.revoke!(now: now)

      expect(described_class.find_alive(token, now: now)).to be_nil
    end

    it '知らない識別子では見つけません' do
      described_class.issue(user: user, now: now)

      expect(described_class.find_alive('unknown', now: now)).to be_nil
    end

    it '空の識別子では見つけません' do
      expect(described_class.find_alive('', now: now)).to be_nil
    end

    it '識別子が無い場合も見つけません' do
      expect(described_class.find_alive(nil, now: now)).to be_nil
    end
  end

  describe '#alive?' do
    it '期限内で取り消されていなければ生きています' do
      session, _token = described_class.issue(user: user, now: now)

      expect(session.alive?(now: now)).to be(true)
    end

    it '期限を過ぎていれば生きていません' do
      session, _token = described_class.issue(user: user, now: now)

      expect(session.alive?(now: now + described_class::LIFETIME + 1.second)).to be(false)
    end
  end

  describe 'ステートレスな構成' do
    it '状態をデータベースに保存します' do
      described_class.issue(user: user, now: now)

      expect(described_class.count).to eq(1)
    end

    it '同じ識別子のハッシュを二重に保存できません' do
      session, _token = described_class.issue(user: user, now: now)
      duplicate = described_class.new(user: user, token_digest: session.token_digest,
                                      expires_at: now + 1.day)

      expect(duplicate).not_to be_valid
    end
  end
end
