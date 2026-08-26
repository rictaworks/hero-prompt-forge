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
# **クォータの確定・返還は、ジョブの結果と一致させます。**
#
#   completed / degraded_completed : 確定します（成果物を提供しています）
#   failed                          : 返還します
class GeneratePromptJob < ApplicationJob
  queue_as :default

  # 何回まで試すかです。**越えたら失敗として記録します。**
  MAX_ATTEMPTS = 3

  # **繰り返しても結果が変わらない誤りです。** その場で失敗として記録します。
  PERMANENT_FAILURES = [
    Generation::PromptGenerationService::ForbiddenInputError,
    Generation::InputNormalizer::InvalidInputError,
    Generation::PromptGenerationService::MissingCopySpaceError,
    Generation::PromptGenerationService::MissingSpecificationsError,
    Generation::PromptGenerationService::VersionMismatchError
  ].freeze

  # **繰り返せば通ることがある誤りです。** 上限まで試します。
  retry_on StandardError, attempts: MAX_ATTEMPTS, wait: :polynomially_longer

  PERMANENT_FAILURES.each do |failure|
    discard_on(failure) { |job, error| job.record_failure(error) }
  end

  # **上限に達したら、失敗として記録します。**
  after_discard { |job, error| job.record_failure(error) }

  def perform(prompt_request_id)
    request = PromptRequest.find(prompt_request_id)
    return unless startable?(request)

    request.transition_to!('generating')
    deliver(request, packages_for(request))
  end

  # 失敗として記録し、クォータを返します。
  #
  # **すでに決着している場合は触れません。** 二度目の記録で状態を壊しません。
  def record_failure(error)
    request = PromptRequest.find_by(id: arguments.first)
    return if request.nil? || %w[queued generating].exclude?(request.status)

    Trace.step('jobs.generate_prompt_failed',
               prompt_request: request.id, error: error.class.name) do
      request.transition_to!('generating') if request.status == 'queued'
      request.transition_to!('failed', rejection_reason: reason_for(error))
      Quota::Reservation.settle!(request)
    end
  end

  private

  # **投入済みの状態だけを進めます。** 二重投入で同じ案を 2 度作りません。
  def startable?(request)
    return true if request.status == 'queued'

    Trace.step('jobs.generate_prompt_skipped',
               prompt_request: request.id, status: request.status) { false }
  end

  def packages_for(request)
    Trace.step('jobs.generate_prompt_started', prompt_request: request.id) do
      Generation::PromptGenerationService
        .new(dictionary: RuleDictionary.current!, people_override: request.project.people_expectation)
        .call(request.inputs.symbolize_keys)
    end
  end

  # 成果物を保存し、状態を進め、クォータを確定します。
  #
  # **保存と状態の更新を、ひとまとまりにします。** 途中で落ちると、
  # 案だけがあって状態が進んでいない記録が残ります。
  def deliver(request, packages)
    degraded = packages.any?(&:degraded?)

    PromptRequest.transaction do
      packages.each { |package| store(request, package) }
      request.transition_to!(degraded ? 'degraded_completed' : 'completed',
                             degraded: degraded,
                             dictionary_version: packages.first.draft.dictionary_version)
    end

    Quota::Reservation.settle!(request)
  end

  def store(request, package)
    PromptOutput.create!(prompt_request: request,
                         variation_no: package.number,
                         composition_type: package.composition_type,
                         main_prompt: package.formatted.to_prompt,
                         negative_prompt: package.formatted.negative_prompt,
                         parameters: package.formatted.parameters,
                         art_direction_note: package.note.to_h.to_json)
  end

  # **理由は種別だけを残します。** 利用者の入力そのものを残しません。
  def reason_for(error)
    error.class.name
  end
end
