# frozen_string_literal: true

module PromptRequests
  # 生成リクエストの受付です（requirements.md 4.1、4.4、12.1、issue #55）。
  #
  # 入力を検め、禁止入力を見つけ、クォータを予約し、ジョブを投入します。
  #
  # **順序に意味があります。**
  #
  #   1. プロジェクトを引きます（他人のものは引けません）
  #   2. 入力を正規化します（誤りは項目ごとに返します）
  #   3. 記録を作ります（`draft`）
  #   4. 禁止入力を調べます（見つかれば `rejected`。**枠を使いません**）
  #      **自由に書いていただいた文章は、記録から落とします**
  #   5. 枠を予約します（使い切っていれば、次回のリセット時刻を添えて断ります）
  #   6. `queued` へ進めて、ジョブを投入します
  #
  # **禁止入力の判定を、枠の予約より先に置きます。** requirements.md 4.1 の 1 は
  # 「差し戻し時はクォータを消費しない」と定めています。順序が入れ替わると、
  # 断った利用者の枠が減ります。
  #
  # **枠の予約を、状態を進めるより先に置きます。** `queued` には
  # `rejected` へ戻る道がありません（requirements.md 12.1）。先に進めてしまうと、
  # 枠を取れなかったときに戻せない記録が残ります。
  #
  # **トランザクションで包みません。** 予約は上限到達の測定を伴います。
  # 外側のトランザクションで包むと、断った事実の記録まで巻き戻ります。
  class Acceptance
    # 自由に書いていただく欄です。**差し戻した記録には残しません。**
    FREE_TEXT_FIELD = 'service_summary'

    # 禁止入力が見つかった場合に投げます。**記録は `rejected` で残ります。**
    class ForbiddenInputError < StandardError
      attr_reader :prompt_request, :reasons

      def initialize(prompt_request:, reasons:)
        @prompt_request = prompt_request
        @reasons = reasons
        super("禁止入力が見つかりました: #{reasons.map(&:kind).inspect}") # 開発者向け
      end
    end

    # @param user [User] 受け付ける利用者です
    # @param dictionary [RuleDictionary] いま使う規則辞書です
    def initialize(user:, dictionary: RuleDictionary.current!)
      @user = user
      @dictionary = dictionary
    end

    # @param project_id [Object] プロジェクトの識別子です
    # @param inputs [Hash, ActionController::Parameters] 入力条件です
    # @return [PromptRequest] 投入済みの生成リクエストです
    def call(project_id:, inputs:)
      project = project_for(project_id)
      normalized = normalized(inputs)
      request = draft(project, normalized)

      ensure_allowed!(request, normalized)
      enqueue(request)
    end

    private

    attr_reader :user, :dictionary

    # **他人のプロジェクトは引けません。** 引けなければ `RecordNotFound` です。
    def project_for(project_id)
      Project.for_user(user).find(project_id)
    end

    # 入力の正規化です。誤りは `InputNormalizer::InvalidInputError` で返ります。
    def normalized(inputs)
      Trace.step('api.prompt_request_normalized') do
        Generation::InputNormalizer.new(dictionary: dictionary).call(inputs)
      end
    end

    # **正規化した入力を保存します。** 受け取ったままの値を残しません。
    def draft(project, normalized)
      PromptRequest.create!(project: project,
                            target_model: normalized[:target_model],
                            inputs: normalized,
                            status: 'draft')
    end

    # **権利に触れる入力は、枠を使う前に止めます。**
    def ensure_allowed!(request, normalized)
      detected = Trace.step('api.forbidden_input_checked') do
        Generation::ForbiddenDetector.new.call(service_summary: normalized[:service_summary])
      end
      return unless detected.forbidden?

      request.transition_to!('rejected',
                             rejection_reason: reason_for(detected.reasons),
                             inputs: kept(request))
      raise ForbiddenInputError.new(prompt_request: request, reasons: detected.reasons)
    end

    # **差し戻した記録から、自由に書いていただく欄を落とします。**
    #
    # 見つかった語を `rejection_reason` へ残さない配慮は、**原文がそのまま
    # 別の列に残っていては意味がありません**（PR #166 のレビューより）。
    # 権利に触れると判定した文章ですので、**実在の方のお名前や商標を含みます。**
    # 差し戻しの記録は保管期間が長く、閲覧できる範囲も広くなります。
    #
    # **生成には使いません。** 差し戻した以上、この文章で作ることはありません。
    # 業種・スタイル系統といった選択肢の値は、**入力し直していただくときの
    # 手がかりになりますので残します。**
    def kept(request)
      request.inputs.except(FREE_TEXT_FIELD)
    end

    # **残すのは種別と直し方の鍵だけです。** 見つかった語そのものを残しません。
    def reason_for(reasons)
      reasons.map(&:kind).uniq.join(',')
    end

    # 枠を予約し、投入します。
    #
    # **予約が先です。** 使い切っていれば `Quota::Reservation::ExhaustedError` が
    # 上がり、記録は `draft` のまま残ります。
    def enqueue(request)
      Quota::Reservation.reserve!(user: user, prompt_request: request)
      request.transition_to!('queued')
      GeneratePromptJob.perform_later(request.id)
      request
    end
  end
end
