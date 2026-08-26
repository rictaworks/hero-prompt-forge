# frozen_string_literal: true

require 'rails_helper'

# 評価メモの記録・更新です（issue #60）。
RSpec.describe '評価メモ API' do # rubocop:disable RSpec/DescribeClass
  let(:user) { User.create!(x_user_id: '6060606060', display_name: 'あおい', plan: 'active') }
  let(:other) { User.create!(x_user_id: '7070707070', display_name: 'ゆう', plan: 'active') }

  def output_for(owner)
    project = Project.create!(user: owner, industry: 'saas', style_family: 'photoreal')
    request = PromptRequest.create!(project: project, target_model: 'midjourney')
    PromptOutput.create!(prompt_request: request, variation_no: 1,
                         composition_type: 'subject_led', main_prompt: 'prompt 1',
                         art_direction_note: '{}')
  end

  def output
    @output ||= output_for(user)
  end

  def path_for(target)
    "/api/v1/prompt_outputs/#{target.id}/evaluation_note"
  end

  def post_note(target: output, **attributes)
    post path_for(target), params: { evaluation_note: attributes }, as: :json
  end

  it '未認証では 401 を返します' do
    post_note(rating: 4)

    expect(response).to have_http_status(:unauthorized)
  end

  describe 'ログインしている場合' do
    before { login_as(user) }

    it '201 を返します' do
      post_note(rating: 4, memo: '余白が読みやすいです。')

      expect(response).to have_http_status(:created)
    end

    it '記録した内容を返します' do
      post_note(rating: 4, memo: '余白が読みやすいです。')

      expect(response.parsed_body).to include('rating' => 4,
                                              'memo' => '余白が読みやすいです。')
    end

    it '評価だけでも記録できます' do
      post_note(rating: 5)

      expect(response).to have_http_status(:created)
    end

    it '所感だけでも記録できます' do
      post_note(memo: '人物の写り方が自然です。')

      expect(response).to have_http_status(:created)
    end

    # **評価も所感も無いメモは、記録する意味がありません。**
    it 'どちらも無ければ 400 を返します' do
      post_note

      expect(response).to have_http_status(:bad_request)
    end

    it '5 段階の外は 400 を返します' do
      post_note(rating: 6)

      expect(response).to have_http_status(:bad_request)
    end

    # **上限に達していても記録できます。** 記録は生成ではありません。
    it '上限に達していても記録できます' do
      Quota::Reservation.reserve!(user: user)

      post_note(rating: 4)

      expect(response).to have_http_status(:created)
    end

    # **1 つの案につき 1 件です。**
    it '2 度目は書き換えます' do
      post_note(rating: 4)
      post_note(rating: 2)

      expect(EvaluationNote.where(prompt_output: output).count).to eq(1)
    end

    it '書き換えた結果を返します' do
      post_note(rating: 4)
      post_note(rating: 2)

      expect(response.parsed_body['rating']).to eq(2)
    end

    it '取り出せます' do
      post_note(rating: 4)

      get path_for(output)

      expect(response.parsed_body['rating']).to eq(4)
    end

    it '記録が無ければ 404 を返します' do
      get path_for(output)

      expect(response).to have_http_status(:not_found)
    end

    it '更新できます' do
      post_note(rating: 4)

      patch path_for(output), params: { evaluation_note: { memo: '直しました。' } }, as: :json

      expect(response.parsed_body['memo']).to eq('直しました。')
    end

    it '記録が無いまま更新すると 404 を返します' do
      patch path_for(output), params: { evaluation_note: { memo: '直しました。' } }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    describe '他人の案の場合' do
      # **他人のメモを操作できません。**
      it '記録では 404 を返します' do
        post_note(target: output_for(other), rating: 4)

        expect(response).to have_http_status(:not_found)
      end

      it '記録を作りません' do
        expect { post_note(target: output_for(other), rating: 4) }
          .not_to change(EvaluationNote, :count)
      end

      it '取り出しでは 404 を返します' do
        theirs = output_for(other)
        EvaluationNote.create!(prompt_output: theirs, rating: 5)

        get path_for(theirs)

        expect(response).to have_http_status(:not_found)
      end

      it '更新では 404 を返します' do
        theirs = output_for(other)
        EvaluationNote.create!(prompt_output: theirs, rating: 5)

        patch path_for(theirs), params: { evaluation_note: { rating: 1 } }, as: :json

        expect(response).to have_http_status(:not_found)
      end

      it '他人のメモを書き換えません' do
        theirs = output_for(other)
        note = EvaluationNote.create!(prompt_output: theirs, rating: 5)

        patch path_for(theirs), params: { evaluation_note: { rating: 1 } }, as: :json

        expect(note.reload.rating).to eq(5)
      end
    end
  end
end
