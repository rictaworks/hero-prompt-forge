# frozen_string_literal: true

# 人の操作であることを確かめます（requirements.md 5.1、issue #61）。
#
# **Bot 対策を自作しません**（CLAUDE.md）。判定は reCAPTCHA へ委ねます。
#
# **合図は見出しで受け取ります。** 本文へ混ぜると、入力の項目として
# 記録へ流れます。**合図は認証の材料であって、生成の入力ではありません。**
#
# ## 環境による分かれ方
#
# **本番では、必ず照合します。** 秘密鍵が設定されていなければ、その場で
# 失敗させます。**鍵の入れ忘れで Bot 対策が黙って無効になる状態を作りません。**
#
# **開発とテストでは、鍵が設定されているときだけ照合します。** 鍵が無ければ
# 飛ばします。**手元で画面を触るたびに Google の鍵を要求しないためです。**
#
# **この分かれ方は、環境だけで決まります。** 要求側の値（見出し・引数・
# クッキー）では切り替わりません。**本番の画面に、飛ばす導線を出しません。**
module VerifiesHumans
  extend ActiveSupport::Concern

  # 合図を受け取る見出しです。
  TOKEN_HEADER = 'X-Recaptcha-Token'

  # 本番で秘密鍵が設定されていない場合に投げます。
  class MissingConfigurationError < StandardError; end

  private

  # 通らなければ例外にします。**通したときだけ先へ進みます。**
  def verify_human!
    return unless verification_required?

    BotProtection::RecaptchaVerifier
      .new
      .call(token: request.headers[TOKEN_HEADER], remote_ip: request.remote_ip)
  end

  # **本番では必ず照合します。**
  def verification_required?
    return ensure_configured! if AppEnvironment.production?

    BotProtection::RecaptchaVerifier.configured?
  end

  # **鍵が無いまま本番を動かしません。**
  def ensure_configured!
    return true if BotProtection::RecaptchaVerifier.configured?

    raise MissingConfigurationError,
          "本番では #{BotProtection::RecaptchaVerifier::SECRET_KEY_VARIABLE} が必要です。" # 開発者向け
  end
end
