# frozen_string_literal: true

# 規則辞書です。
#
# 生成に用いた版を後から追えるようにするため、**公開済みの版は書き換えません。**
# 内容を変える場合は新しい版を作ります。
class RuleDictionary < ApplicationRecord
  # 公開済みの版を書き換えようとした場合に投げます。
  class PublishedVersionError < StandardError; end

  validates :version, presence: true, uniqueness: true

  scope :published, -> { where.not(published_at: nil) }

  before_update :reject_published_change

  # いま使う版を返します。公開済みのうち、最後に公開したものです。
  def self.current(now: Time.current)
    published.where(published_at: ..now).order(published_at: :desc).first
  end

  def published?
    published_at.present?
  end

  def publish!(now: Time.current)
    raise PublishedVersionError, 'すでに公開済みです。' if published? # 開発者向け

    update_column(:published_at, now) # rubocop:disable Rails/SkipsModelValidations
    reload
  end

  # 業種ごとの既定値を返します。定義が無ければ例外にします。
  def defaults_for(industry)
    industry_defaults.fetch(industry.to_s) do
      raise KeyError, "業種の既定値がありません: #{industry.inspect}" # 開発者向け
    end
  end

  private

  def reject_published_change
    return if published_at_was.blank?
    return if (changes.keys - %w[updated_at]).empty?

    raise PublishedVersionError, '公開済みの版は書き換えられません。' # 開発者向け
  end
end
