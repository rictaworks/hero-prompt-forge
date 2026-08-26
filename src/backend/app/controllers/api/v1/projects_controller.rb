# frozen_string_literal: true

module Api
  module V1
    # プロジェクトの作成・一覧・更新です（issue #57）。
    #
    # **他人のプロジェクトを操作できません。** 引くところを必ず `for_user` に
    # 通します。見つからない場合と他人のものを、同じ返し方にします。
    class ProjectsController < BaseController
      rescue_from ActiveRecord::RecordInvalid, with: :render_invalid_record

      def index
        render json: { projects: owned.recent_first.map { |item| representation(item) } },
               status: :ok
      end

      def create
        project = Project.create!(user: current_user, **attributes)

        render json: representation(project), status: :created
      end

      def update
        project = owned.find(params.expect(:id))
        project.update!(**attributes)

        render json: representation(project), status: :ok
      end

      private

      # **必ず利用者で絞り込みます。** 絞り込みを飛ばす経路を作りません。
      def owned
        Project.for_user(current_user)
      end

      # **受け取る項目を列挙します。** `params` を直に渡しません。
      def attributes
        params.expect(project: [:name, :industry, :style_family,
                                { brand_settings: {} }]).to_h.symbolize_keys
      end

      def representation(project)
        {
          id: project.id,
          name: project.name,
          industry: project.industry,
          style_family: project.style_family,
          brand_settings: project.brand_settings,
          created_at: project.created_at.iso8601,
          updated_at: project.updated_at.iso8601
        }
      end
    end
  end
end
