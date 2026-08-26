# frozen_string_literal: true

module Api
  module V1
    # 評価メモの記録・更新です（issue #60）。
    #
    # **上限に達していても記録できます。** 記録は生成ではありません。
    # 枠の判定をこの経路に置きません。
    #
    # **他人のメモを操作できません。** 案を引くところを必ず利用者で
    # 絞り込みます。**メモではなく案で絞ります。** メモは案に属しますので、
    # 案の持ち主が決まればメモの持ち主も決まります。
    class EvaluationNotesController < BaseController
      rescue_from ActiveRecord::RecordInvalid, with: :render_invalid_record

      def show
        note = output.evaluation_note
        raise ActiveRecord::RecordNotFound if note.nil?

        render json: representation(note), status: :ok
      end

      # **1 つの案につき 1 件です。** すでにあれば書き換えます。
      def create
        note = output.evaluation_note
        return update_existing(note) if note

        created = EvaluationNote.create!(prompt_output: output, **attributes)

        render json: representation(created), status: :created
      end

      def update
        note = output.evaluation_note
        raise ActiveRecord::RecordNotFound if note.nil?

        update_existing(note)
      end

      private

      # **案を利用者で絞ります。** 他人の案には届きません。
      def output
        @output ||= PromptOutput
                    .joins(prompt_request: :project)
                    .where(projects: { user_id: current_user.id })
                    .find(params.expect(:prompt_output_id))
      end

      def update_existing(note)
        note.update!(**attributes)

        render json: representation(note), status: :ok
      end

      def attributes
        params.expect(evaluation_note: %i[rating memo]).to_h.symbolize_keys
      end

      def representation(note)
        {
          id: note.id,
          prompt_output_id: note.prompt_output_id,
          rating: note.rating,
          memo: note.memo,
          created_at: note.created_at.iso8601,
          updated_at: note.updated_at.iso8601
        }
      end
    end
  end
end
