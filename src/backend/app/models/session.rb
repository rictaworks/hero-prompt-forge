# frozen_string_literal: true

require 'digest'
require 'securerandom'

# ログインの状態です。
#
# **識別子そのものを保存しません。** ハッシュだけを保存し、照合はハッシュで行います。
# データベースの内容が漏れても、そのままログインに使えないようにするためです。
class Session < ApplicationRecord
  belongs_to :user

  LIFETIME = 14.days
  TOKEN_BYTES = 32

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :alive, lambda { |now = Time.current|
    where(revoked_at: nil).where(expires_at: now..)
  }

  # 新しいログイン状態を作ります。
  # @return [Array(Session, String)] 保存した行と、利用者へ渡す識別子
  def self.issue(user:, now: Time.current)
    token = SecureRandom.urlsafe_base64(TOKEN_BYTES)
    session = create!(user: user, token_digest: digest(token), expires_at: now + LIFETIME)
    [session, token]
  end

  # 識別子から、生きているログイン状態を探します。
  def self.find_alive(token, now: Time.current)
    return nil if token.blank?

    alive(now).find_by(token_digest: digest(token))
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  def revoke!(now: Time.current)
    update!(revoked_at: now)
  end

  def alive?(now: Time.current)
    revoked_at.nil? && expires_at > now
  end
end
