# frozen_string_literal: true

require 'rails_helper'

# 管理画面の資格情報です（requirements.md 5.2、issue #177）。
#
# **通った名前だけを実施者にします。** 記録の「実施者」は、実際に管理の操作を
# 行えた人でなければ意味がありません。通らなかった名前を控えると、誰でも
# 好きな名前を監査の記録へ残せます。
RSpec.describe Admin::Credentials do
  let(:name) { 'admin-for-spec' }
  let(:password) { 'password-for-spec' }
  let(:credentials) { described_class.new(name: name, password: password) }

  describe '#actor_for' do
    it '資格情報が揃っていれば、その名前を返します' do
      expect(credentials.actor_for(name, password)).to eq(name)
    end

    # **合言葉だけが合っていても通しません。** 片方の照合結果で早く抜けると、
    # もう片方の照合を省いたことになります。
    it '利用者名が違えば、実施者を返しません' do
      expect(credentials.actor_for('stranger', password)).to be_nil
    end

    it '合言葉が違えば、実施者を返しません' do
      expect(credentials.actor_for(name, 'wrong')).to be_nil
    end

    it '利用者名と合言葉の両方が違えば、実施者を返しません' do
      expect(credentials.actor_for('stranger', 'wrong')).to be_nil
    end

    it '空の資格情報では、実施者を返しません' do
      expect(credentials.actor_for('', '')).to be_nil
    end

    it '値が無い場合でも、実施者を返しません' do
      expect(credentials.actor_for(nil, nil)).to be_nil
    end

    # **`&` を使い、両方の照合を必ず行います**（時間の差で、利用者名と
    # 合言葉のどちらが違うのかが漏れないようにするためです）。**`&&` に
    # 変えると、利用者名が違った時点で合言葉の照合を省きます。**
    # コメントで守っているだけの状態でしたので、直接の検めを足します
    # （PR #182 のレビューより）。
    it '利用者名が違っても、合言葉の照合を省きません' do
      allow(ActiveSupport::SecurityUtils).to receive(:secure_compare).and_call_original

      credentials.actor_for('stranger', password)

      expect(ActiveSupport::SecurityUtils).to have_received(:secure_compare).twice
    end

    it '合言葉が違っても、両方の照合を行います' do
      allow(ActiveSupport::SecurityUtils).to receive(:secure_compare).and_call_original

      credentials.actor_for(name, 'wrong')

      expect(ActiveSupport::SecurityUtils).to have_received(:secure_compare).twice
    end
  end

  describe '.from_env' do
    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with(described_class::USER_NAME_KEY, nil).and_return(env_name)
      allow(ENV).to receive(:fetch).with(described_class::PASSWORD_KEY, nil).and_return(env_password)
    end

    describe '環境変数が揃っているとき' do
      let(:env_name) { name }
      let(:env_password) { password }

      it '環境変数の資格情報で照合します' do
        expect(described_class.from_env.actor_for(name, password)).to eq(name)
      end
    end

    # **未設定なら、その場で失敗させます。** 空文字と照合して通すと、
    # 資格情報を設定し忘れた環境で、管理画面が誰でも開ける状態になります。
    describe '利用者名が未設定のとき' do
      let(:env_name) { nil }
      let(:env_password) { password }

      it 'その場で失敗させます' do
        expect { described_class.from_env }
          .to raise_error(described_class::MissingCredentialsError)
      end
    end

    describe '合言葉が未設定のとき' do
      let(:env_name) { name }
      let(:env_password) { nil }

      it 'その場で失敗させます' do
        expect { described_class.from_env }
          .to raise_error(described_class::MissingCredentialsError)
      end
    end

    describe '値が空文字のとき' do
      let(:env_name) { '' }
      let(:env_password) { '' }

      it 'その場で失敗させます' do
        expect { described_class.from_env }
          .to raise_error(described_class::MissingCredentialsError)
      end
    end
  end
end
