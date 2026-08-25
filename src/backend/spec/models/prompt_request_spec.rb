# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PromptRequest do
  let(:user) { User.create!(x_user_id: '1234567890', display_name: 'あお') }
  let(:project) do
    Project.create!(user: user, industry: 'saas', style_family: 'photoreal')
  end

  def build_request(**overrides)
    described_class.new({ project: project, target_model: 'midjourney' }.merge(overrides))
  end

  describe '検証' do
    it '生成モデルがあれば保存できます' do
      expect(build_request).to be_valid
    end

    it '初期の状態は下書きです' do
      expect(build_request.tap(&:save!).status).to eq('draft')
    end

    it '生成モデルが無ければ保存できません' do
      expect(build_request(target_model: nil)).not_to be_valid
    end

    it '定義されていない生成モデルを受け付けません' do
      expect(build_request(target_model: 'unknown')).not_to be_valid
    end

    it '仕様の生成モデルをすべて持ちます' do
      expect(described_class::TARGET_MODELS)
        .to contain_exactly('midjourney', 'dalle', 'stable_diffusion', 'nano_banana')
    end
  end

  describe '状態の遷移' do
    subject(:request) { build_request.tap(&:save!) }

    it '下書きから待ち行列へ進めます' do
      request.transition_to!('queued')

      expect(request.status).to eq('queued')
    end

    it '下書きから差し戻しへ進めます' do
      request.transition_to!('rejected', rejection_reason: '禁止入力を検出しました。')

      expect(request.status).to eq('rejected')
    end

    it '待ち行列から生成中へ進めます' do
      request.transition_to!('queued')
      request.transition_to!('generating')

      expect(request.status).to eq('generating')
    end

    it '生成中から完了へ進めます' do
      request.transition_to!('queued')
      request.transition_to!('generating')
      request.transition_to!('completed')

      expect(request.status).to eq('completed')
    end

    it '生成中から縮退の完了へ進めます' do
      request.transition_to!('queued')
      request.transition_to!('generating')
      request.transition_to!('degraded_completed', degraded: true)

      expect([request.status, request.degraded]).to eq(['degraded_completed', true])
    end

    it '失敗から待ち行列へ戻せます' do
      request.transition_to!('queued')
      request.transition_to!('generating')
      request.transition_to!('failed')
      request.transition_to!('queued')

      expect(request.status).to eq('queued')
    end
  end

  describe '許されない遷移' do
    subject(:request) { build_request.tap(&:save!) }

    it '下書きから生成中へは進めません' do
      expect { request.transition_to!('generating') }
        .to raise_error(described_class::InvalidTransitionError)
    end

    it '下書きから完了へは進めません' do
      expect { request.transition_to!('completed') }
        .to raise_error(described_class::InvalidTransitionError)
    end

    it '差し戻しからは進めません' do
      request.transition_to!('rejected')

      expect { request.transition_to!('queued') }
        .to raise_error(described_class::InvalidTransitionError)
    end

    it '整理済みからは進めません' do
      request.transition_to!('queued')
      request.transition_to!('generating')
      request.transition_to!('completed')
      request.transition_to!('archived')

      expect { request.transition_to!('queued') }
        .to raise_error(described_class::InvalidTransitionError)
    end

    it '許されない遷移では状態が変わりません' do
      expect { request.transition_to!('completed') }
        .to raise_error(described_class::InvalidTransitionError)

      expect(request.reload.status).to eq('draft')
    end
  end

  describe '成果物の提供' do
    subject(:request) { build_request.tap(&:save!) }

    it '完了は成果物を提供した状態です' do
      request.update!(status: 'completed')

      expect(request).to be_delivered
    end

    it '縮退の完了も成果物を提供した状態です' do
      request.update!(status: 'degraded_completed')

      expect(request).to be_delivered
    end

    it '失敗は成果物を提供していません' do
      request.update!(status: 'failed')

      expect(request).not_to be_delivered
    end

    it '差し戻しは成果物を提供していません' do
      request.update!(status: 'rejected')

      expect(request).not_to be_delivered
    end
  end

  describe '他人のリクエスト' do
    it '所有者で絞り込めます' do
      mine = build_request.tap(&:save!)
      other = User.create!(x_user_id: '9876543210', display_name: 'べつのひと')
      other_project = Project.create!(user: other, industry: 'saas', style_family: 'photoreal')
      described_class.create!(project: other_project, target_model: 'dalle')

      expect(described_class.for_user(user)).to contain_exactly(mine)
    end
  end
end
