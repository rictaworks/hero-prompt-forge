# frozen_string_literal: true

module Auth
  # 手動再判定です。
  #
  # フォロー直後は、判定サービス側の同期がまだ済んでいないことがあります。
  # 利用者の操作で判定を取り直せるようにします。
  #
  # 連続した要求は判定サービスへの負荷になるため、**クールダウンを必須とします。**
  class RecheckService
    # クールダウン中に要求された場合に投げます。
    class CooldownError < StandardError
      attr_reader :available_at

      def initialize(available_at)
        @available_at = available_at
        super('再判定はまだ要求できません。') # 開発者向け
      end
    end

    COOLDOWN = 5.minutes

    def initialize(plan_updater: PlanUpdater.new, clock: Time)
      @plan_updater = plan_updater
      @clock = clock
    end

    # @return [Boolean] プラン値を反映したかどうか
    def call(user)
      raise CooldownError, user.recheck_available_at if cooling_down?(user)

      Trace.step('plan.recheck', user_id: user.id) do
        # 先にクールダウンを立てます。判定が失敗しても、連続要求を許しません。
        now = clock.current
        user.update!(recheck_available_at: now + COOLDOWN)

        applied = plan_updater.refresh(user)
        user.update!(plan_checked_at: now) if applied
        applied
      end
    end

    # 残りのクールダウンを秒で返します。要求できる場合は 0 です。
    def cooldown_seconds(user)
      return 0 unless cooling_down?(user)

      (user.recheck_available_at - clock.current).ceil
    end

    private

    attr_reader :plan_updater, :clock

    def cooling_down?(user)
      available_at = user.recheck_available_at
      return false if available_at.nil?

      available_at > clock.current
    end
  end
end
