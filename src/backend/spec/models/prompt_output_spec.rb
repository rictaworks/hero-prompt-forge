# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PromptOutput do
  let(:user) { User.create!(x_user_id: '1234567890', display_name: 'あお') }
  let(:project) { Project.create!(user: user, industry: 'saas', style_family: 'photoreal') }
  let(:request) { PromptRequest.create!(project: project, target_model: 'midjourney') }

  def build_output(**overrides)
    described_class.new({
      prompt_request: request,
      variation_no: 1,
      composition_type: 'subject_led',
      main_prompt: 'a coffee stand counter, 50mm lens',
      art_direction_note: 'コピースペースの可読性を確認してください。'
    }.merge(overrides))
  end

  describe '検証' do
    it '必要な項目がそろえば保存できます' do
      expect(build_output).to be_valid
    end

    it 'メインプロンプトが無ければ保存できません' do
      expect(build_output(main_prompt: nil)).not_to be_valid
    end

    it 'アートディレクションノートが無ければ保存できません' do
      expect(build_output(art_direction_note: nil)).not_to be_valid
    end

    it 'ネガティブプロンプトは空でも保存できます' do
      expect(build_output(negative_prompt: nil)).to be_valid
    end

    it '構図の種別が無ければ保存できません' do
      expect(build_output(composition_type: nil)).not_to be_valid
    end

    it '定義されていない構図の種別を受け付けません' do
      expect(build_output(composition_type: 'unknown')).not_to be_valid
    end
  end

  describe '案の番号' do
    it '1から3までを受け付けます' do
      expect([1, 2, 3].all? { |n| build_output(variation_no: n).valid? }).to be(true)
    end

    it '0 を受け付けません' do
      expect(build_output(variation_no: 0)).not_to be_valid
    end

    it '4 を受け付けません' do
      expect(build_output(variation_no: 4)).not_to be_valid
    end

    it '同じリクエストで同じ番号を二重に持てません' do
      build_output.save!

      expect(build_output).not_to be_valid
    end

    it '別のリクエストなら同じ番号を持てます' do
      build_output.save!
      other = PromptRequest.create!(project: project, target_model: 'dalle')

      expect(build_output(prompt_request: other)).to be_valid
    end
  end

  describe '構図の種別' do
    it '仕様の3種を持ちます' do
      expect(described_class::COMPOSITION_TYPES)
        .to contain_exactly('subject_led', 'environment_led', 'abstract_background')
    end

    it '3案は構図が互いに異なります' do
      described_class::COMPOSITION_TYPES.each_with_index do |type, index|
        build_output(variation_no: index + 1, composition_type: type).save!
      end

      expect(request.prompt_outputs.pluck(:composition_type).uniq.size).to eq(3)
    end
  end

  describe '並び' do
    it '番号の順に並びます' do
      build_output(variation_no: 3, composition_type: 'abstract_background').save!
      build_output(variation_no: 1).save!
      build_output(variation_no: 2, composition_type: 'environment_led').save!

      expect(request.prompt_outputs.in_order.pluck(:variation_no)).to eq([1, 2, 3])
    end
  end

  describe '縮退の印' do
    it 'リクエストが縮退なら案にも印が付きます' do
      request.update!(degraded: true)

      expect(build_output.degraded?).to be(true)
    end

    it '通常の生成なら印は付きません' do
      expect(build_output.degraded?).to be(false)
    end
  end
end
