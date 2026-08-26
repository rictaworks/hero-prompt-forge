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

  # ブランド設定のうち、人物が写る見込みの上書きの鍵です（issue #147）。
  #
  # **規則辞書は全利用者で共有される単一のマスタです。** 1 社のために編集すると、
  # 全社の出力が変わります。**業種の中の個別事情は、ここで持ちます。**
  #
  #   EC でも、アパレル・コスメはモデル着用のヒーローが主流です
  #   飲食でも、料理単体のヒーローと、シェフの手元のヒーローがあります
  #   製造でも、製品だけを写したい場合があります
  PEOPLE_KEY = 'people'

  belongs_to :user

  validates :industry, presence: true, inclusion: { in: INDUSTRIES }
  validates :style_family, presence: true, inclusion: { in: STYLE_FAMILIES }
  validates :name, length: { maximum: 100 }, allow_nil: true
  validate :people_override_is_a_choice

  scope :for_user, ->(user) { where(user: user) }
  scope :recent_first, -> { order(created_at: :desc) }

  # 人物が写る見込みの上書きです。**指定が無ければ `nil` です。**
  # @return [String, nil]
  def people_expectation
    brand_settings[PEOPLE_KEY]
  end

  private

  # **選択肢の外の値を保存させません。** 書き間違えた上書きが黙って無視されると、
  # 利用者は「指定したのに反映されない」状態になります。
  def people_override_is_a_choice
    value = people_expectation
    return if value.nil? || Generation::PeopleExpectation::CHOICES.include?(value)

    errors.add(:brand_settings, :inclusion)
  end
end
