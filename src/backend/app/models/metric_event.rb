# frozen_string_literal: true

# 測定軸の記録です（requirements.md 7.1）。
#
# **仕様が定める軸だけを扱います。** 定義に無い指標を増やしません。
#
# **個人を特定できる形で記録しません。** 残すのは、軸の名前・クォータ日・件数
# だけです。**利用者の識別子を持ちません。**
class MetricEvent < ApplicationRecord
  # 仕様が定める測定軸です（requirements.md 7.1）。
  #
  #   quota_exhausted : 上限到達の発生数（追加需要の観測に用います）
  #   quota_reclaimed : クォータ返還の発生数（生成失敗の間接指標です）
  #
  # **ここに無い軸は記録できません。** 定義に無い指標を増やさないためです。
  AXES = %w[quota_exhausted quota_reclaimed].freeze

  validates :axis, presence: true, inclusion: { in: AXES }
  validates :occurred_on, presence: true
  validates :count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :axis, uniqueness: { scope: :occurred_on }

  scope :for_axis, ->(axis) { where(axis: axis) }
  scope :between, ->(from, to) { where(occurred_on: from..to) }
end
