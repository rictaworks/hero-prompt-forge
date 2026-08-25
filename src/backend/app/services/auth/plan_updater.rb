# frozen_string_literal: true

module Auth
  # 判定サービスの応答を、利用者のプラン値へ反映します。
  #
  # 機能側はプラン値のみを参照します。ここが、判定手段と機能側の境目です。
  # 判定手段を変更・廃止しても、機能側の実装に影響を与えません。
  #
  # 状態の遷移（requirements.md 12.2）
  #   unverified --> active  : 判定サービスが full を返した
  #   unverified --> pending : 判定サービスが restricted を返した
  #   pending    --> active  : 手動再判定で full を返した
  #   pending    --> pending : 再判定でも restricted だった
  #   active     --> active  : 判定サービスの障害時も保持済みの値を維持する
  class PlanUpdater
    # 判定サービスの応答が想定と違う場合に投げます。
    class UnknownPlanError < StandardError; end

    # 判定サービスのプラン値と、本アプリのプラン値の対応です。
    PLAN_BY_DECISION = {
      'full' => 'active',
      'restricted' => 'pending'
    }.freeze

    def initialize(gate_client: FollowerGateClient.new)
      @gate_client = gate_client
    end

    # 判定を取り直して反映します。
    #
    # 判定サービスへ到達できない場合は、保持済みのプラン値を変えずに false を返します。
    # 「つながらないから利用できることにする」も「つながらないから拒否する」も行いません。
    #
    # @return [Boolean] 反映したかどうか
    def refresh(user)
      Trace.step('plan.refresh', user_id: user.id) do
        decision = gate_client.decide(x_user_id: user.x_user_id)
        apply(user, decision)
      end
    rescue FollowerGateClient::UnavailableError
      # 新規判定のみを止めます。既存の利用者を締め出しません。
      false
    end

    # 取得済みの判定を反映します。
    # @return [Boolean] 反映したかどうか
    # rubocop:disable-next Naming/PredicateMethod -- 述語ではなく、反映の可否を返す手続きです。
    def apply(user, decision)
      # 確定していない判定では、保持済みの値を変えません。
      return false unless decision.confirmed

      plan = PLAN_BY_DECISION.fetch(decision.plan) do
        raise UnknownPlanError, "判定サービスが未知のプラン値を返しました: #{decision.plan.inspect}" # 開発者向け
      end

      user.update!(plan: plan)
      true
    end

    private

    attr_reader :gate_client
  end
end
