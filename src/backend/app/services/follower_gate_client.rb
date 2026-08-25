# frozen_string_literal: true

require 'net/http'
require 'json'

# フォロワー判定サービス（x-follower-gate）の呼び出しです。
#
# **フォロワー判定を本アプリで実装しません。** X API を直接呼ばず、
# フォロワーの一覧も保持しません。数値のユーザーIDを渡し、プラン値を受け取ります。
#
# 接続先と資格情報は環境変数から読みます。判定サービスのドメインをソースへ書きません。
class FollowerGateClient
  # 判定サービスへ到達できない、または応答が想定と違う場合に投げます。
  # 呼び出し側は、保持済みのプラン値を正として扱い、新規判定のみを止めます。
  class UnavailableError < StandardError; end

  # 資格情報が受け付けられない場合に投げます。設定の誤りです。
  class UnauthorizedError < StandardError; end

  # 渡した識別子が形式として不正な場合に投げます。
  class InvalidUserIdError < StandardError; end

  X_USER_ID_FORMAT = /\A[0-9]{1,19}\z/
  DEFAULT_TIMEOUT_SECONDS = 5

  # 判定サービスからの応答です。値を解釈し直さず、そのまま保持します。
  Decision = Struct.new(
    :plan,               # 'full' / 'restricted'
    :decided_at,         # 判定が確定した日時
    :recheck_available,  # 手動再判定を要求できるか
    :inquiry_id,         # 拒否された利用者が運用者へ申告するための値
    :confirmed,          # false の場合、判定サービス側の都合で確定していません
    keyword_init: true
  )

  def initialize(
    base_url: ENV.fetch('FOLLOWER_GATE_BASE_URL'),
    client_id: ENV.fetch('FOLLOWER_GATE_CLIENT_ID'),
    credential: ENV.fetch('FOLLOWER_GATE_CREDENTIAL'),
    timeout_seconds: DEFAULT_TIMEOUT_SECONDS
  )
    @base_url = base_url
    @client_id = client_id
    @credential = credential
    @timeout_seconds = timeout_seconds
  end

  # @param x_user_id [String] 数値のユーザーID
  # @return [Decision]
  def decide(x_user_id:)
    raise InvalidUserIdError, "x_user_id の形式が不正です: #{x_user_id.inspect}" unless valid_id?(x_user_id) # 開発者向け

    Trace.step('follower_gate.decide', x_user_id: x_user_id) do
      response = get('/internal/decision', x_user_id: x_user_id)
      to_decision(parse(response))
    end
  end

  private

  attr_reader :base_url, :client_id, :credential, :timeout_seconds

  def valid_id?(value)
    value.to_s.match?(X_USER_ID_FORMAT)
  end

  def get(path, params)
    uri = URI.join(base_url, path)
    uri.query = URI.encode_www_form(params)

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{client_id}:#{credential}"
    request['Accept'] = 'application/json'

    perform(uri, request)
  end

  def perform(uri, request)
    Net::HTTP.start(uri.hostname, uri.port,
                    use_ssl: uri.scheme == 'https',
                    open_timeout: timeout_seconds,
                    read_timeout: timeout_seconds) do |http|
      http.request(request)
    end
  rescue StandardError => e
    # 例外の中身に接続先や資格情報が混ざらないよう、種別のみを伝えます。
    raise UnavailableError, "判定サービスへ到達できません: #{e.class}" # 開発者向け
  end

  def parse(response)
    ensure_success(response)
    JSON.parse(response.body)
  rescue JSON::ParserError
    raise UnavailableError, '判定サービスの応答を解釈できません。' # 開発者向け
  end

  def ensure_success(response)
    return if response.is_a?(Net::HTTPOK)

    case response
    when Net::HTTPUnauthorized
      raise UnauthorizedError, '判定サービスが資格情報を受け付けませんでした。' # 開発者向け
    when Net::HTTPBadRequest
      raise InvalidUserIdError, '判定サービスが識別子を受け付けませんでした。' # 開発者向け
    else
      raise UnavailableError, "判定サービスの応答が想定と異なります: #{response.code}" # 開発者向け
    end
  end

  def to_decision(body)
    plan = body['plan']
    raise UnavailableError, '判定サービスの応答にプラン値がありません。' if plan.nil? # 開発者向け

    Decision.new(
      plan: plan,
      decided_at: body['decided_at'],
      recheck_available: body['recheck_available'],
      inquiry_id: body['inquiry_id'],
      confirmed: body['confirmed']
    )
  end
end
