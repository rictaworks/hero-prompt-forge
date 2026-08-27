# frozen_string_literal: true

# 管理者が行った操作の記録です（requirements.md 4.4、issue #66、#67）。
#
# **実施者と日時を残します。** クォータの手動リセットと手動再判定は、
# 利用者の状態を管理者が直接変える操作です。
#
# **合言葉を残しません。** 残すのは利用者名だけです。
#
# **`details` に秘匿値を入れません。** 入れてよいのは、後から辿るために
# 要る値（クォータ日など）だけです。
class AdminAction < ApplicationRecord
  # 操作の種別です。**ここに無い種別は記録できません。**
  # 種別の名前を呼び出す側へ書き写しません。
  RECHECKED_PLAN = 'rechecked_plan'
  RESET_QUOTA = 'reset_quota'
  PUBLISHED_DICTIONARY = 'published_dictionary'

  ACTIONS = [RECHECKED_PLAN, RESET_QUOTA, PUBLISHED_DICTIONARY].freeze

  belongs_to :user, optional: true

  validates :actor, presence: true
  validates :action, presence: true, inclusion: { in: ACTIONS }

  scope :recent_first, -> { order(created_at: :desc) }

  # 記録を残します。**実施者が空なら、その場で失敗させます。**
  def self.record!(actor:, action:, user: nil, details: {})
    create!(actor: actor, action: action, user: user, details: details)
  end
end
