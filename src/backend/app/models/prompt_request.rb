# frozen_string_literal: true

# 生成リクエストです。
#
# 状態は requirements.md 12.1 の遷移に従います。
# **定義されていない遷移は拒否します。** 状態を直接書き換えず、必ず遷移の手続きを通します。
#
#   draft              --> queued / rejected
#   queued             --> generating
#   generating         --> completed / degraded_completed / failed
#   failed             --> queued（同一リクエストの再実行）
#   completed          --> archived
#   degraded_completed --> archived
class PromptRequest < ApplicationRecord
  # 定義されていない遷移を試みた場合に投げます。
  class InvalidTransitionError < StandardError; end

  STATUSES = %w[
    draft queued generating completed degraded_completed failed rejected archived
  ].freeze

  # 生成モデルです。requirements.md 4.1 の選択肢に対応します。
  TARGET_MODELS = %w[midjourney dalle stable_diffusion nano_banana].freeze

  # 許される遷移です。ここに無い組み合わせは拒否します。
  TRANSITIONS = {
    'draft' => %w[queued rejected],
    'queued' => %w[generating],
    'generating' => %w[completed degraded_completed failed],
    'failed' => %w[queued],
    'completed' => %w[archived],
    'degraded_completed' => %w[archived],
    'rejected' => [],
    'archived' => []
  }.freeze

  # 成果物を提供した状態です。クォータを確定します。
  DELIVERED_STATUSES = %w[completed degraded_completed].freeze

  belongs_to :project
  has_one :user, through: :project

  validates :status, inclusion: { in: STATUSES }
  validates :target_model, presence: true, inclusion: { in: TARGET_MODELS }

  scope :for_user, ->(user) { joins(:project).where(projects: { user_id: user.id }) }
  scope :recent_first, -> { order(created_at: :desc) }

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

  def delivered?
    DELIVERED_STATUSES.include?(status)
  end

  def terminal?
    TRANSITIONS.fetch(status, []).empty?
  end
end
