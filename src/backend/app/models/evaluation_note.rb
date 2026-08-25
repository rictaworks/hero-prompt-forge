# frozen_string_literal: true

# 評価メモです。
#
# 生成画像を実際に作った結果の所感を記録します。
# **上限に達していても記録できます。** 記録は生成ではないためです。
class EvaluationNote < ApplicationRecord
  RATING_RANGE = 1..5
  MEMO_MAX_LENGTH = 2000

  belongs_to :prompt_output

  validates :rating, inclusion: { in: RATING_RANGE }, allow_nil: true
  validates :memo, length: { maximum: MEMO_MAX_LENGTH }, allow_nil: true
  # 1つの案につき1件です。データベース側の一意制約と対にします。
  validates :prompt_output_id, uniqueness: true
  validate :must_have_content

  scope :for_user, lambda { |user|
    joins(prompt_output: { prompt_request: :project })
      .where(projects: { user_id: user.id })
  }

  private

  # 評価も所感も無いメモは、記録する意味がありません。
  def must_have_content
    return if rating.present? || memo.present?

    errors.add(:base, :blank)
  end
end
