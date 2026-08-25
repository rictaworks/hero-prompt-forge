# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EvaluationNote do
  let(:user) { User.create!(x_user_id: '1234567890', display_name: 'あお') }
  let(:project) { Project.create!(user: user, industry: 'saas', style_family: 'photoreal') }
  let(:request) { PromptRequest.create!(project: project, target_model: 'midjourney') }
  let(:output) do
    PromptOutput.create!(prompt_request: request, variation_no: 1,
                         composition_type: 'subject_led',
                         main_prompt: 'a coffee stand counter',
                         art_direction_note: 'コピースペースを確認してください。')
  end

  def build_note(**overrides)
    described_class.new({ prompt_output: output, rating: 4 }.merge(overrides))
  end

  describe '検証' do
    it '評価があれば保存できます' do
      expect(build_note).to be_valid
    end

    it '所感だけでも保存できます' do
      expect(build_note(rating: nil, memo: '色が明るすぎました。')).to be_valid
    end

    it '評価も所感も無ければ保存できません' do
      expect(build_note(rating: nil, memo: nil)).not_to be_valid
    end

    it '案が無ければ保存できません' do
      expect(build_note(prompt_output: nil)).not_to be_valid
    end

    it '1つの案につき1件までです' do
      build_note.save!

      expect(build_note).not_to be_valid
    end
  end

  describe '評価の範囲' do
    it '1から5までを受け付けます' do
      expect((1..5).all? { |n| build_note(rating: n).valid? }).to be(true)
    end

    it '0 を受け付けません' do
      expect(build_note(rating: 0)).not_to be_valid
    end

    it '6 を受け付けません' do
      expect(build_note(rating: 6)).not_to be_valid
    end
  end

  describe '所感の長さ' do
    it '上限までは保存できます' do
      expect(build_note(memo: 'あ' * described_class::MEMO_MAX_LENGTH)).to be_valid
    end

    it '上限を超えると保存できません' do
      expect(build_note(memo: 'あ' * (described_class::MEMO_MAX_LENGTH + 1))).not_to be_valid
    end
  end

  describe '他人のメモ' do
    it '所有者で絞り込めます' do
      mine = build_note.tap(&:save!)

      expect(described_class.for_user(user)).to contain_exactly(mine)
    end

    it '他人のものは絞り込みに含まれません' do
      other = User.create!(x_user_id: '9876543210', display_name: 'べつのひと')
      other_project = Project.create!(user: other, industry: 'saas', style_family: 'photoreal')
      other_request = PromptRequest.create!(project: other_project, target_model: 'dalle')
      other_output = PromptOutput.create!(prompt_request: other_request, variation_no: 1,
                                          composition_type: 'subject_led',
                                          main_prompt: 'x',
                                          art_direction_note: '確認してください。')
      theirs = described_class.create!(prompt_output: other_output, rating: 3)

      expect(described_class.for_user(user)).not_to include(theirs)
    end
  end

  describe '上限との関係' do
    it '上限に達していても記録できます' do
      # 記録は生成ではないため、クォータの状態に依存しません。
      expect(build_note).to be_valid
    end
  end
end
