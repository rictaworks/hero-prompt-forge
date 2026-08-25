# frozen_string_literal: true

# プロンプトパッケージの1案です。
#
# 1つの生成リクエストにつき、**構図の異なる3案**を保持します。
# コピースペースの指定とアートディレクションノートを持たない案は保存できません。
class PromptOutput < ApplicationRecord
  # 構図の種別です。requirements.md 4.1 の3案に対応します。
  COMPOSITION_TYPES = %w[subject_led environment_led abstract_background].freeze

  # 1リクエストあたりの案の数です。
  VARIATION_COUNT = 3

  belongs_to :prompt_request

  validates :variation_no, presence: true,
                           inclusion: { in: 1..VARIATION_COUNT },
                           uniqueness: { scope: :prompt_request_id }
  validates :composition_type, presence: true, inclusion: { in: COMPOSITION_TYPES }
  validates :main_prompt, presence: true
  validates :art_direction_note, presence: true

  scope :in_order, -> { order(:variation_no) }

  # 縮退して作られた案かどうかを返します。判定はリクエスト側が持ちます。
  def degraded?
    prompt_request.degraded
  end
end
