# frozen_string_literal: true

require 'rails_helper'

# 検証で使う文言が、すべて `config/locales/ja.yml` にあることを確かめます。
#
# 本アプリは日本語のみを提供し、未定義の文言を例外にします
# （`raise_on_missing_translations`）。標準の日本語訳を持たないため、
# **文言が欠けていると、検証の失敗ではなく文言の欠落として失敗します。**
# 起きる例外の種類が変わり、原因の切り分けが遠回りになります（issue #124）。
#
# **新しい検証を足したときに、文言の足し忘れをこのテストが知らせます。**
# 対応表に無い種類の検証を見つけた場合に投げます。
class UnknownValidatorError < StandardError; end

RSpec.describe '検証で使う文言' do
  # 検証の種類から、使う文言の鍵を求めます。
  #
  # **対応表に無い種類の検証は、その場で失敗させます。**
  # 空を返して通すと、対応表に無い検証を足したときに鍵が 1 つも求まらず、
  # テストは緑のまま通ります。**issue #124 の症状そのものが再発しても
  # 気づけません。** 対応表への追記を、人の記憶ではなくテストが強制します。
  #
  # 自前の検証（`validate :method`）は `validators` に現れません。
  # そちらは `custom_keys` で扱います。
  # 条件によらず 1 つの文言だけを使う検証です。
  def fixed_keys
    { ActiveRecord::Validations::PresenceValidator => %i[blank],
      ActiveRecord::Validations::UniquenessValidator => %i[taken],
      ActiveModel::Validations::InclusionValidator => %i[inclusion],
      ActiveModel::Validations::ExclusionValidator => %i[exclusion],
      ActiveModel::Validations::FormatValidator => %i[invalid] }
  end

  # 指定した条件によって、使う文言が変わる検証です。
  def varying_keys
    { ActiveModel::Validations::LengthValidator => method(:length_keys),
      ActiveModel::Validations::NumericalityValidator => method(:numericality_keys) }
  end

  # **継承した検証も引けるようにします。**
  # `ActiveRecord::Validations::LengthValidator` は
  # `ActiveModel::Validations::LengthValidator` を継承しています。
  def matched(table, validator)
    _, value = table.find { |klass, _| validator.is_a?(klass) }
    value
  end

  def keys_for(validator)
    fixed = matched(fixed_keys, validator)
    return fixed if fixed

    varying = matched(varying_keys, validator)
    return varying.call(validator) if varying

    raise UnknownValidatorError, "対応表に無い検証です: #{validator.class}" # 開発者向け
  end

  # 数値の検証は、指定した条件によって使う文言が変わります。
  def numericality_keys(validator)
    { only_integer: :not_an_integer,
      greater_than_or_equal_to: :greater_than_or_equal_to,
      greater_than: :greater_than,
      less_than_or_equal_to: :less_than_or_equal_to,
      less_than: :less_than }
      .filter_map { |option, key| key if validator.options.key?(option) }
      .push(:not_a_number)
  end

  # 長さの検証は、指定した条件によって使う文言が変わります。
  def length_keys(validator)
    { maximum: :too_long, minimum: :too_short, is: :wrong_length }
      .filter_map { |option, key| key if validator.options.key?(option) }
  end

  # 自前の検証（`validate :method` の中で `errors.add` する形）と、
  # 関連の欠落（`belongs_to`）が使う文言です。
  #
  # 自前の検証はコードを読まないと分かりませんので、ここへ列挙します。
  #   - `evaluation_note.rb` の `must_have_content` が `:blank`
  #   - `preset.rb` の `conditions_must_be_allowed` が `:invalid`
  #   - `belongs_to` の欠落が `:required`
  #   - 保存に失敗したことを開発者へ知らせる `RecordInvalid` が `:record_invalid`
  def custom_keys
    %i[blank invalid required record_invalid]
  end

  def models
    Rails.application.eager_load!
    ApplicationRecord.descendants.reject(&:abstract_class?)
  end

  def defined_message?(key)
    I18n.t("activerecord.errors.messages.#{key}")
    true
  rescue I18n::MissingTranslationData
    false
  end

  it '調べる対象のモデルがあります' do
    expect(models).not_to be_empty
  end

  it 'すべての検証の文言が定義されています' do
    used = models.flat_map(&:validators)
                 .flat_map { |validator| keys_for(validator) }
                 .uniq

    expect(used.reject { |key| defined_message?(key) }).to be_empty
  end

  it '対応表に無い種類の検証を見つけたら失敗します' do
    unknown = ActiveModel::Validations::AcceptanceValidator.new(attributes: [:terms],
                                                                class: User)

    expect { keys_for(unknown) }.to raise_error(UnknownValidatorError)
  end

  it '自前の検証と関連の欠落で使う文言が定義されています' do
    expect(custom_keys.reject { |key| defined_message?(key) }).to be_empty
  end

  # 実際に起きる例外の種類をそろえます。issue #124 の症状そのものです。
  describe '起きる例外の種類' do
    it '利用者を欠いた保存は、検証の失敗になります' do
      expect { QuotaConsumption.create!(quota_day: Date.new(2026, 8, 26)) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'クォータ日を欠いた保存も、検証の失敗になります' do
      user = User.create!(x_user_id: '9001', display_name: '文言の確認', plan: 'active')

      expect { QuotaConsumption.create!(user: user, quota_day: nil) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end

    it '書式が違う保存も、検証の失敗になります' do
      expect { User.create!(x_user_id: 'not-a-number', display_name: '文言の確認') }
        .to raise_error(ActiveRecord::RecordInvalid)
    end

    it '長すぎる保存も、検証の失敗になります' do
      user = User.create!(x_user_id: '9002', display_name: '文言の確認', plan: 'active')

      expect { Project.create!(user: user, industry: 'saas', style_family: 'photoreal', name: 'あ' * 101) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
