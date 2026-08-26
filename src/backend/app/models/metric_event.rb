# frozen_string_literal: true

# 測定軸の記録です（requirements.md 7.1）。
#
# **仕様が定める軸だけを扱います。** 定義に無い指標を増やしません。
#
# **個人を特定できる形で記録しません。** 残すのは、軸の名前・クォータ日・件数
# の 3 つだけです。**利用者の識別子を持ちません。**
#
# **作成時刻・更新時刻も持ちません。** 作成時刻は「その日にはじめて上限へ
# 達した瞬間」をマイクロ秒で残しますので、`quota_consumptions`（利用者の
# 識別子を持ちます）や記録と時刻で突き合わせると、**どなたかが絞り込めます。**
# 件数の少ない日ほど絞り込めます（PR #164 のレビューより）。
class MetricEvent < ApplicationRecord
  # 仕様が定める測定軸です（requirements.md 7.1）。
  #
  #   quota_exhausted : 上限到達の発生数（追加需要の観測に用います）
  #   quota_reclaimed : クォータ返還の発生数（生成失敗の間接指標です）
  #
  # **ここに無い軸は記録できません。** 定義に無い指標を増やさないためです。
  # **軸の名前は、ここだけに書きます。** 呼び出す側へ書き写しません。
  # 書き写すと、片方だけを直したときに `ensure_axis!` が静かに落ちる側へ倒れます。
  QUOTA_EXHAUSTED = 'quota_exhausted'
  QUOTA_RECLAIMED = 'quota_reclaimed'

  AXES = [QUOTA_EXHAUSTED, QUOTA_RECLAIMED].freeze

  validates :axis, presence: true, inclusion: { in: AXES }
  validates :occurred_on, presence: true
  validates :occurrences, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  # **本当の守りは一意索引です。** この検証は、別の経路から `save` した場合の
  # 保険です。数え上げは `upsert` で行いますので、この検証を通りません。
  validates :axis, uniqueness: { scope: :occurred_on }

  scope :for_axis, ->(axis) { where(axis: axis) }
  scope :between, ->(from, to) { where(occurred_on: from..to) }
end
