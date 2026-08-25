# frozen_string_literal: true

# プリセットです。
#
# 入力条件の組み合わせを名前付きで保存します。
# **他人のプリセットは参照できません。** 参照は必ず `for_user` を通します。
class Preset < ApplicationRecord
  # 保存できる入力条件の項目です。ここに無い項目は保存しません。
  # 画面が増えたときに、意図しない値が紛れ込まないようにするためです。
  ALLOWED_CONDITION_KEYS = %w[
    industry style_family target_model service_summary
    brand_tone brand_colors copy_space_position aspect_ratio
  ].freeze

  belongs_to :user

  validates :name, presence: true, length: { maximum: 50 },
                   uniqueness: { scope: :user_id }
  validate :conditions_must_be_allowed

  scope :for_user, ->(user) { where(user: user) }
  scope :by_name, -> { order(:name) }

  private

  def conditions_must_be_allowed
    return if input_conditions.blank?

    unknown = input_conditions.keys.map(&:to_s) - ALLOWED_CONDITION_KEYS
    return if unknown.empty?

    errors.add(:input_conditions, :invalid)
  end
end
