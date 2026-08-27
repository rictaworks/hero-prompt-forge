# frozen_string_literal: true

# 生成を非同期で行うジョブです（requirements.md 4.2、12.1、issue #54）。
#
# **待たせません。** プロンプトの組み立ては、規則の適用から整形まで幾つもの段を
# 通ります。要求のたびに待たせると、通信が切れただけで結果が失われます。
#
# **リトライの上限を決めます。** 越えたら失敗として記録し、**クォータを返します。**
# 当日中に作り直していただけます（requirements.md 4.4）。
#
# **決まった結果になる誤りは、繰り返しません。** 入力の誤り・禁止入力・
# 規則辞書の不備は、何度試しても同じ結果です。**その場で失敗として記録します。**
#
# **投入し直しは、仕事をやり直します。** 1 回目で `generating` になった後に
# 投入し直された回を見送ると、**上限へ決して届かず、失敗の記録もクォータの
# 返還も起きません**（PR #165 のレビューで実測されました）。同じジョブの
# 投入し直し（`executions` が 2 以上）だけが、`generating` から再開できます。
#
# **仕事を始める権利は、行に錠をかけて取ります。** 状態を読んでから書くまでの
# 間に錠をかけないと、`queued` のうちに読んだ 2 つ目の働き手が、**出来上がった
# 生成リクエストを「生成中」へ巻き戻せます**（同レビューで実測されました）。
#
# **クォータの確定・返還は、ジョブの結果と一致させます。**
#
#   completed / degraded_completed : 確定します（成果物を提供しています）
#   failed                          : 返還します
#
# **確定だけが残った場合も、投入し直しで拾い直します。** 確定はひとまとまりの
# 外で行いますので、そこで落ちると「成果物はあるのに枠が予約のまま」が残ります。
# 放っておくと、日をまたいだときに予約そのものを止めます。
class GeneratePromptJob < ApplicationJob
  queue_as :default

  # 何回まで試すかです。**越えたら失敗として記録します。**
  MAX_ATTEMPTS = 3

  # **繰り返しても結果が変わらない誤りです。** その場で失敗として記録します。
  #
  # 入力の誤り・禁止入力に加え、**規則辞書の不備**を含めます。公開済みの版が
  # 無い、渡し忘れ、内容が選択肢の外、業種の既定値が無い、のいずれも、
  # **何度試しても同じ結果です**（PR #165 のレビューより）。
  PERMANENT_FAILURES = [
    Generation::PromptGenerationService::ForbiddenInputError,
    Generation::PromptGenerationService::MissingDictionaryError,
    Generation::PromptGenerationService::MissingCopySpaceError,
    Generation::PromptGenerationService::MissingSpecificationsError,
    Generation::PromptGenerationService::VersionMismatchError,
    Generation::InputNormalizer::InvalidInputError,
    Generation::InputNormalizer::InvalidDictionaryError,
    RuleDictionary::MissingCurrentError,
    RuleDictionary::MissingDefaultsError
  ].freeze

  # **働き手が落ちたと見なすまでの時間です。**
  #
  # 働き手が異常終了すると、仕事は待ち行列へ戻りますが、**戻ってくるのは
  # 投入時の `executions` です。** 投入し直しとして見分けられませんので、
  # `generating` のまま永久に取り残されます（PR #165 の 2 回目のレビューで
  # 実測されました）。**時間で見分けます。**
  #
  # ## この値を 2 分にした根拠（issue #169）
  #
  # **待ち行列が仕事を戻す窓より短くしなければ、拾い直しは一度も発火しません。**
  #
  # | 事実 | 値 |
  # |---|---|
  # | 本番の待ち行列 | Solid Queue |
  # | 掴まれたままの仕事を戻すまで | **およそ 5 分**（`process_alive_threshold` の既定。上書きしていません） |
  # | ジョブ自身の仕事の長さ | 磨きの読み取り待ち 20 秒 × 案の数。**分の単位に届きません** |
  #
  # 戻ってきた回の「動きの無さ」は**およそ 5 分ぶん**です。15 分では届かず、
  # その回は見送られ、しかも正常終了しますので**二度と投入されません**
  # （PR #165 の 3 回目のレビューで実測されました）。
  #
  # **短くしすぎません。** 組み立ての途中で別の働き手が横入りします。
  # 組み立ては、磨きの待ち時間（1 案あたり最大 20 秒 × 3 案 = 60 秒）を含めても
  # **2 分に届きません。** 5 分より短く、組み立ての長さより長い値として
  # **2 分**を採ります。
  #
  # **`ReclaimPromptRequestsJob` の間隔も、この値に合わせます。**
  STALE_AFTER = 2.minutes

  # **繰り返せば通ることがある誤りです。** 上限まで試します。
  #
  # **`StandardError` で受けません。** 網が広すぎると、書き間違い
  # （`NoMethodError`）や一意性の違反まで飲み込み、**誤りが記録にも
  # 利用者にも現れないまま消えます**（PR #165 のレビューで実測されました）。
  # 挙げるのは、時間をおけば通ることがあるものだけです。
  TRANSIENT_FAILURES = [
    ActiveRecord::Deadlocked,
    ActiveRecord::LockWaitTimeout,
    ActiveRecord::QueryCanceled,
    ActiveRecord::ConnectionNotEstablished,
    ActiveRecord::ConnectionTimeoutError,
    Timeout::Error,
    IOError
  ].freeze

  # **想定していない誤りも、失敗として記録してから外へ出します。**
  #
  # 握りつぶしません。**そのうえで、生成リクエストを `generating` のまま
  # 取り残しません。** 記録を残さずに外へ出すと、利用者から見て
  # 「いつまでも生成中」になり、当日の枠も戻りません。
  #
  # **先に登録します。** `rescue_from` は後から登録したものが優先しますので、
  # この下の `retry_on` ・ `discard_on` が先に当たります。
  rescue_from(StandardError) do |error|
    record_failure(error)
    raise error
  end

  # **上限に達したら、失敗として記録して終えます。**
  #
  # **ここでは投げ直しません。** 時間をおけば通ることがある誤りを上限まで
  # 試したうえでの、想定された行き止まりです。**状態・理由・クォータの返還・
  # 記録がすべて残りますので、握りつぶしにはあたりません。**
  # 想定していない誤り（下の `rescue_from`）とは、扱いを分けます。
  # **塊を渡すのは、投げ直させないためだけです。**
  # 記録は `after_discard` が引き受けます。`retry_on` は塊を呼んだ直後に
  # `after_discard` を呼びますので、**ここで記録すると 2 度走ります**
  # （PR #165 の 2 回目のレビューで実測されました）。
  retry_on(*TRANSIENT_FAILURES, attempts: MAX_ATTEMPTS, wait: :polynomially_longer) { nil }

  # **繰り返しません。** 記録は `after_discard` が一度だけ行います。
  discard_on(*PERMANENT_FAILURES)

  # **上限に達した場合と、繰り返さない誤りの場合の、共通の後始末です。**
  after_discard { |job, error| job.record_failure(error) }

  def perform(prompt_request_id)
    request = PromptRequest.find(prompt_request_id)
    return settle(request) if awaiting_settlement?(request)
    return unless claimed?(request)

    deliver(request, packages_for(request))
  end

  # 失敗として記録し、クォータを返します。
  #
  # **すでに決着している場合は触れません。** 二度目の記録で状態を壊しません。
  #
  # **`queued` のままでも、いったん `generating` を通します。** ジョブが
  # 動き出している以上、生成は始まっています（requirements.md 12.1 は
  # `queued` から直に `failed` へ進む道を持ちません）。
  def record_failure(error)
    request = PromptRequest.find_by(id: arguments.first)
    return if request.nil? || PromptRequest::UNSETTLED_STATUSES.exclude?(request.status)

    Trace.step('jobs.generate_prompt_failed',
               prompt_request: request.id, error: error.class.name) do
      request.transition_to!(PromptRequest::GENERATING) if request.status == PromptRequest::QUEUED
      request.transition_to!(PromptRequest::FAILED, rejection_reason: reason_for(error))
      Quota::Reservation.settle!(request)
    end
  end

  private

  # 仕事を始める権利を取ります。
  #
  # **行に錠をかけてから状態を見ます。** 読むところと書くところの間に他の
  # 働き手が割り込むと、出来上がった生成リクエストを「生成中」へ巻き戻せます。
  #
  # **錠は、権利を取る間だけです。** 組み立ての間は外します。組み立ては
  # 外への問い合わせを含みますので、その間ずっと錠をかけると行が長く塞がります。
  # **拾ったときは、必ず行を新しくします**（issue #169）。
  #
  # `queued` からは状態が進みますので、行が更新されます。**しかし置き去りの
  # `generating` を拾った場合、状態は変わりません。** 行が一切更新されないと、
  # **置き去りの行に対しては錠が効きません。** 2 人が同時に拾って両方が組み立て
  # 切り、**同じ組み立てを 2 度行い（有償の呼び出しが二重にかかります）、
  # 勝てなかった側が理由の分からない失敗として記録に残ります**
  # （PR #165 の 3 回目のレビューで実測されました）。
  #
  # **持ち時間を新しくすれば、2 人目は「置き去りではない」と見て見送ります。**
  def claimed?(request)
    request.with_lock do
      next skipped(request) unless resumable?(request)

      if request.status == PromptRequest::QUEUED
        request.transition_to!(PromptRequest::GENERATING)
      else
        request.touch # rubocop:disable Rails/SkipsModelValidations
      end
      true
    end
  end

  # **投入済みの状態だけを進めます。** 二重投入で同じ案を 2 度作りません。
  #
  # **同じジョブの投入し直しだけが、`generating` から再開できます。**
  # `executions` は、そのジョブが何回目の実行かを表します。2 回目以降は、
  # 1 回目が `generating` まで進めたあと落ちた回です。**別の投入は 1 回目
  # ですので、`generating` を見たら見送ります。**
  def resumable?(request)
    return true if request.status == PromptRequest::QUEUED
    return false unless request.status == PromptRequest::GENERATING

    retrying? || stale?(request)
  end

  def retrying?
    executions.to_i > 1
  end

  # **働き手が落ちて置き去りになった行を、拾い直します。**
  # 見分けるのは時間です。`executions` では見分けられません。
  def stale?(request)
    request.updated_at <= STALE_AFTER.ago
  end

  def skipped(request)
    Trace.step('jobs.generate_prompt_skipped',
               prompt_request: request.id, status: request.status) { false }
  end

  # **決着だけが残っている場合です。**
  #
  # 生成そのものは終わっている（成果物を提供したか、失敗として記録した）のに、
  # 枠が予約のまま残っています。**確定も返還も、ひとまとまりの外で行います**
  # ので、そこで落ちるとこの形になります。
  #
  # **提供できた場合と、失敗した場合の両方を拾います。** 片方だけに立て直しを
  # 用意すると、鏡像の側が取り残されます（PR #165 の 2 回目のレビューより）。
  #
  # **放っておくと、日をまたいだときに予約そのものを止めます。**
  def awaiting_settlement?(request)
    return false unless request.delivered? || request.status == PromptRequest::FAILED

    reserved?(request)
  end

  def reserved?(request)
    QuotaConsumption.exists?(prompt_request_id: request.id, status: 'reserved')
  end

  def settle(request)
    Trace.step('jobs.generate_prompt_settled',
               prompt_request: request.id, status: request.status) do
      Quota::Reservation.settle!(request)
    end
  end

  def packages_for(request)
    Trace.step('jobs.generate_prompt_started', prompt_request: request.id) do
      Generation::PromptGenerationService
        .new(dictionary: RuleDictionary.current!,
             people_override: request.project.people_expectation)
        .call(request.inputs.symbolize_keys)
    end
  end

  # 成果物を収め、クォータを確定します。
  #
  # **保存と状態の更新のひとまとまりは `PromptRequests::Delivery` が持ちます。**
  #
  # **クォータの確定は、そのひとまとまりの外です。** 外れた場合は、
  # 投入し直しの `awaiting_settlement?` が拾い直します。
  def deliver(request, packages)
    stored = Trace.step('jobs.generate_prompt_stored',
                        prompt_request: request.id, packages: packages.size) do
      PromptRequests::Delivery.new(request).call(packages)
    end

    settle(stored)
  end

  # **理由は種別だけを残します。** 利用者の入力そのものを残しません。
  def reason_for(error)
    error.class.name
  end
end
