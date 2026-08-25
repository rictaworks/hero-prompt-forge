# frozen_string_literal: true

# プロジェクトです。
#
# サイト単位で入力条件を保存します。**他人のプロジェクトは参照できません。**
# 参照の可否は、必ず `for_user` を通して絞り込みます。
class Project < ApplicationRecord
  # 業種です。requirements.md 4.1 の選択肢に対応します。
  INDUSTRIES = %w[
    saas restaurant medical education real_estate
    manufacturing professional_services ecommerce beauty other
  ].freeze

  # スタイル系統です。requirements.md 2 の4分類に対応します。
  STYLE_FAMILIES = %w[photoreal illustration three_d abstract].freeze

  belongs_to :user

  validates :industry, presence: true, inclusion: { in: INDUSTRIES }
  validates :style_family, presence: true, inclusion: { in: STYLE_FAMILIES }
  validates :name, length: { maximum: 100 }, allow_nil: true

  scope :for_user, ->(user) { where(user: user) }
  scope :recent_first, -> { order(created_at: :desc) }
end
