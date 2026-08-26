# frozen_string_literal: true

# 死活監視のための応答です（requirements.md 7.3）。
#
# **データベースへ到達できることまで含めて答えます。** 「アプリが起動している」
# だけでは、利用者から見た稼働を表せません。データベースへ届かなければ、
# 生成も履歴の閲覧もできません。
#
# 外形監視サービスが呼びます。**認証を求めません。** 認証を求めると、監視の
# 設定に資格情報を置くことになり、資格情報の置き場所が増えます。
#
# **応答に内部の作りを含めません。** 表の名前・接続先・版などを出すと、
# 攻める側に手がかりを与えます（requirements.md 5.2）。
class HealthController < ApplicationController
  # データベースへ到達できるかどうかを確かめる、いちばん軽い問い合わせです。
  REACHABILITY_QUERY = 'SELECT 1'

  def show
    if database_reachable?
      render json: { status: 'ok' }, status: :ok
    else
      render json: { status: 'unavailable' }, status: :service_unavailable
    end
  end

  private

  # **握りつぶしません。記録へ残してから、到達できない旨を返します。**
  # 静かに 503 を返すだけでは、原因を追えません。
  def database_reachable?
    ActiveRecord::Base.connection.execute(REACHABILITY_QUERY)
    true
  rescue ActiveRecord::ActiveRecordError, PG::Error => e
    Rails.logger.error("[health] データベースへ到達できません error=#{e.class}") # 開発者向け
    false
  end
end
