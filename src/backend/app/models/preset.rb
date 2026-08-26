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

  # 入力条件の大きさの上限です（JSON にしたときの文字数）。
  #
  # **鍵を絞っても、値の大きさは絞れません**（PR #167 のレビューより）。
  # サービス概要の上限（1000 文字）に、他の項目ぶんの余裕を足した値です。
  MAX_CONDITIONS_LENGTH = 2000

  belongs_to :user

  validates :name, presence: true, length: { maximum: 50 },
                   uniqueness: { scope: :user_id }
  validate :conditions_must_be_allowed
  validate :conditions_must_be_small_enough

  scope :for_user, ->(user) { where(user: user) }
  scope :by_name, -> { order(:name) }

  private

  def conditions_must_be_allowed
    return if input_conditions.blank?

    unknown = input_conditions.keys.map(&:to_s) - ALLOWED_CONDITION_KEYS
    return if unknown.empty?

    errors.add(:input_conditions, :invalid)
  end

  # **大きさに上限を置きます。** 鍵を絞っても、値の大きさは絞れません。
  def conditions_must_be_small_enough
    return if input_conditions.blank?
    return if input_conditions.to_json.length <= MAX_CONDITIONS_LENGTH

    errors.add(:input_conditions, :too_long, count: MAX_CONDITIONS_LENGTH)
  end
end
