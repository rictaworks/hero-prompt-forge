# frozen_string_literal: true

module Api
  module V1
    # プリセットの保存・一覧・呼び出しです（issue #58）。
    #
    # **他人のプリセットを操作できません。** 引くところを必ず `for_user` に
    # 通します。見つからない場合と他人のものを、同じ返し方にします。
    class PresetsController < BaseController
      rescue_from ActiveRecord::RecordInvalid, with: :render_invalid_record

      def index
        render json: { presets: owned.by_name.map { |item| representation(item) } }, status: :ok
      end

      def show
        render json: representation(owned.find(params.expect(:id))), status: :ok
      end

      def create
        preset = Preset.create!(user: current_user, **attributes)

        render json: representation(preset), status: :created
      end

      def update
        preset = owned.find(params.expect(:id))
        preset.update!(**attributes)

        render json: representation(preset), status: :ok
      end

      private

      def owned
        Preset.for_user(current_user)
      end

      # **保存できる入力条件は `Preset::ALLOWED_CONDITION_KEYS` に閉じています。**
      # ここで絞らず、モデルの検証に検めさせます。**二重に書き写しません。**
      def attributes
        params.expect(preset: [:name, { input_conditions: {} }]).to_h.symbolize_keys
      end

      def representation(preset)
        {
          id: preset.id,
          name: preset.name,
          input_conditions: preset.input_conditions,
          created_at: preset.created_at.iso8601,
          updated_at: preset.updated_at.iso8601
        }
      end
    end
  end
end
