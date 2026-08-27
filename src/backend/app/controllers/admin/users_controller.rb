# frozen_string_literal: true

module Admin
  # 利用者とプラン値の管理です（requirements.md 4.3、6、issue #66）と、
  # クォータの手動リセットです（requirements.md 4.4、issue #67）。
  #
  # **機能側はプラン値のみを参照します。** ここは、その値を確かめ、
  # 判定を取り直す入口です。**プラン値を手で書き換える経路を作りません。**
  # 手で書き換えられると、判定手段と機能側の境目が崩れます。
  #
  # **実施者と日時を必ず記録します。** 利用者の状態を管理者が直接変える操作
  # ですので、誰が・いつ・誰に対して行ったのかを残します。
  class UsersController < ApplicationController
    rescue_from Auth::RecheckService::CooldownError, with: :render_cooling_down

    def index
      @users = User.order(created_at: :desc)
    end

    def show
      @user = User.find(params.expect(:id))
      @quota_day = Quota::QuotaDay.of
      @consumption = QuotaConsumption.find_for(@user, @quota_day)
      @actions = AdminAction.where(user: @user).recent_first.limit(20)
    end

    # **手動再判定です**（requirements.md 6）。
    #
    # **クールダウンを必ず通します。** 管理画面からでも、判定サービスへの
    # 連続した要求を許しません。
    def recheck
      user = User.find(params.expect(:id))
      applied = Auth::RecheckService.new.call(user)
      AdminAction.record!(actor: admin_actor, action: AdminAction::RECHECKED_PLAN,
                          user: user, details: { 'applied' => applied })

      redirect_to admin_user_path(user), notice: notice_for(applied)
    end

    # **本日の消費をリセットします**（requirements.md 4.4）。
    #
    # **状態の遷移の定めを通しません。** 確定済みからは、どの状態へも
    # 進めない定めです。手動リセットは、その定めの外にある運用の操作です。
    #
    # **リセットしたことを記録へ残します**（`reset_by_admin`）。
    def reset_quota
      user = User.find(params.expect(:id))
      quota_day = Quota::QuotaDay.of
      consumption = QuotaConsumption.find_for(user, quota_day)

      return redirect_to(admin_user_path(user), alert: t('admin.users.no_quota')) if consumption.nil?
      return redirect_to(admin_user_path(user), alert: t('admin.users.in_progress')) if running?(consumption)

      reset!(user, consumption, quota_day)
    end

    private

    # **生成中の枠には当てません**（PR #175 のレビュー・要修正 1）。
    #
    # 動いているジョブは、終わったときに枠を決着させます。先に返してしまうと、
    # **決着する相手が見つからず、成果物は届いているのにジョブが失敗のまま
    # 残ります。** 終わるのを待ってからリセットしてください。
    def running?(consumption)
      consumption.status == 'reserved'
    end

    def reset!(user, consumption, quota_day)
      consumption.reset_by_admin!
      AdminAction.record!(actor: admin_actor, action: AdminAction::RESET_QUOTA,
                          user: user, details: { 'quota_day' => quota_day.to_s })

      redirect_to admin_user_path(user), notice: t('admin.users.quota_reset')
    end

    def notice_for(applied)
      applied ? t('admin.users.rechecked') : t('admin.users.recheck_unavailable')
    end

    def render_cooling_down(error)
      redirect_to admin_user_path(params[:id]),
                  alert: t('admin.users.cooling_down',
                           available_at: I18n.l(error.available_at, format: :reset_at))
    end
  end
end
