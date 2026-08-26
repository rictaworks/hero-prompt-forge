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

  # ブランド設定のうち、トーンとブランドカラーの鍵です。
  # 列の説明（「トーン・カラー等」）に対応します。
  TONE_KEY = 'tone'
  COLORS_KEY = 'colors'

  # ブランド設定に置ける鍵です。**ここに無い鍵は保存しません。**
  #
  # `name` が 100 文字、評価メモが 2000 文字と決まっているのに、
  # **この列だけ無制限にしません**（PR #167 のレビューより）。
  # 読まない値を預かり続けると、預かった側の負担だけが増えます。
  ALLOWED_BRAND_SETTING_KEYS = [PEOPLE_KEY, TONE_KEY, COLORS_KEY].freeze

  # ブランド設定の大きさの上限です（JSON にしたときの文字数）。
  #
  # **上限を置きます。** 置かないと、1 件で数十万文字を預かれます。
  MAX_BRAND_SETTINGS_LENGTH = 2000

  belongs_to :user

  validates :industry, presence: true, inclusion: { in: INDUSTRIES }
  validates :style_family, presence: true, inclusion: { in: STYLE_FAMILIES }
  validates :name, length: { maximum: 100 }, allow_nil: true
  validate :brand_settings_is_a_hash
  validate :brand_settings_keys_are_allowed
  validate :brand_settings_is_small_enough
  validate :people_override_is_a_choice

  scope :for_user, ->(user) { where(user: user) }
  scope :recent_first, -> { order(created_at: :desc) }

  # 人物が写る見込みの上書きです。**指定が無ければ `nil` です。**
  # @return [String, nil]
  def people_expectation
    brand_settings.is_a?(Hash) ? brand_settings[PEOPLE_KEY] : nil
  end

  private

  # **連想配列以外を保存させません。** 検証の中で例外が出ると、
  # 「値が正しくない」ではなく「保存の仕組みが壊れた」ように見えます
  # （PR #158 のレビューより）。
  def brand_settings_is_a_hash
    return if brand_settings.is_a?(Hash)

    errors.add(:brand_settings, :invalid)
  end

  # **決まっていない鍵を保存させません。** 読まない値を預かり続けると、
  # 預かった側の負担だけが増えます（PR #167 のレビューより）。
  def brand_settings_keys_are_allowed
    return unless brand_settings.is_a?(Hash)

    unknown = brand_settings.keys.map(&:to_s) - ALLOWED_BRAND_SETTING_KEYS
    return if unknown.empty?

    errors.add(:brand_settings, :invalid)
  end

  # **大きさに上限を置きます。** 置かないと、1 件で数十万文字を預かれます。
  def brand_settings_is_small_enough
    return unless brand_settings.is_a?(Hash)
    return if brand_settings.to_json.length <= MAX_BRAND_SETTINGS_LENGTH

    errors.add(:brand_settings, :too_long, count: MAX_BRAND_SETTINGS_LENGTH)
  end

  # **選択肢の外の値を保存させません。** 書き間違えた上書きが黙って無視されると、
  # 利用者は「指定したのに反映されない」状態になります。
  def people_override_is_a_choice
    value = people_expectation
    return if value.nil? || Generation::PeopleExpectation::CHOICES.include?(value)

    errors.add(:brand_settings, :inclusion)
  end
end
