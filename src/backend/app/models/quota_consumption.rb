# frozen_string_literal: true

# クォータの消費です。
#
# プロンプトの生成は1アカウントにつき1日1回です（requirements.md 4.4）。
# 「1日」は JST 03:00 を境界とするクォータ日で、境界の計算は
# Quota::QuotaDay が持ちます。
#
# **同じ日に2件作れないことは、データベースの一意制約で担保します。**
# 検証だけでは、二重送信や並列投入で同じ日に2件通る余地が残ります。
#
# 状態は次のとおりです。
#
#   reserved  --> confirmed : 成果物を提供したため確定します
#   reserved  --> refunded  : 生成に失敗したため返還します
#   refunded  --> reserved  : 返還後、当日中に作り直します
#
# 返還しても記録は残します。消費の履歴を後から追えるようにするためです。
class QuotaConsumption < ApplicationRecord
  # 定義されていない遷移を試みた場合に投げます。
  class InvalidTransitionError < StandardError; end

  STATUSES = %w[reserved confirmed refunded].freeze

  # 許される遷移です。ここに無い組み合わせは拒否します。
  TRANSITIONS = {
    'reserved' => %w[confirmed refunded],
    'confirmed' => [],
    'refunded' => %w[reserved]
  }.freeze

  belongs_to :user
  # 予約はリクエストの作成前に行います。そのため、予約した時点では空です。
  belongs_to :prompt_request, optional: true

  validates :quota_day, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: :quota_day }

  scope :for_day, ->(quota_day) { where(quota_day: quota_day) }
  scope :outstanding, -> { where(status: 'reserved') }

  # 枠を使っている状態です。返還済みは使っていません。
  def consuming?
    %w[reserved confirmed].include?(status)
  end

  # 状態を進めます。定義されていない遷移は拒否します。
  def transition_to!(next_status, **attributes)
    allowed = TRANSITIONS.fetch(status) do
      raise InvalidTransitionError, "未知の状態です: #{status.inspect}" # 開発者向け
    end

    unless allowed.include?(next_status.to_s)
      raise InvalidTransitionError,
            "許されない遷移です: #{status.inspect} -> #{next_status.inspect}" # 開発者向け
    end

    update!(attributes.merge(status: next_status.to_s))
  end

  # **管理者による手動リセットです**（requirements.md 4.4、issue #67）。
  #
  # **状態の遷移の定めを通しません。** 確定済みからは、どの状態へも進めない
  # 定めです（`TRANSITIONS`）。手動リセットは、その定めの外にある**運用の
  # 操作**です。定めに穴を開ける代わりに、専用の入口を 1 つだけ設けます。
  #
  # **リセットしたことを記録へ残します**（`reset_by_admin`）。
  # **誰がいつ行ったのかは `AdminAction` が持ちます。**
  #
  # **返還した扱いにします。** 当日中の生成をもう一度できるようにするためです。
  def reset_by_admin!
    update!(status: 'refunded', reset_by_admin: true)
  end

  # そのクォータ日の消費を返します。無ければ nil です。
  def self.find_for(user, quota_day)
    find_by(user_id: user.id, quota_day: quota_day)
  end
end
