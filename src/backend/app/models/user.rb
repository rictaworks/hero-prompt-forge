# frozen_string_literal: true

# 利用者です。
#
# 機能側は plan（プラン値）のみを参照します。フォロー判定の有無から
# 機能側が直接判定しません。判定手段を変更・廃止しても、機能側の実装に
# 影響を与えないことを設計上の要件としています。
class User < ApplicationRecord
  # unverified : 判定前です
  # active     : 利用できます
  # pending    : 利用条件を満たしていません（再判定で active になり得ます）
  enum :plan, { unverified: 'unverified', active: 'active', pending: 'pending' },
       validate: true

  validates :x_user_id, presence: true, uniqueness: true,
                        format: { with: /\A\d+\z/ }
  validates :display_name, presence: true

  # 機能側が参照する唯一の判定です。
  def authorized?
    active?
  end
end
