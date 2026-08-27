# frozen_string_literal: true

# ブラウザ操作の確認（Playwright）のための記録を用意します（issue #173）。
#
# **自動検査のデータベースは空です。** `db/seeds.rb` が作るのは規則辞書だけで、
# 案件も生成の要求も 1 件もありません。一方、画面の確認は**すでに出来上がった
# 生成の記録**を開きます（`/requests/1` ・ `/requests/1/result` ・ `/requests/1/notes`）。
# **記録が無いと、11 例が「画面に何も出ない」として落ちます**（PR #179 のレビューで実測されました）。
#
# **開発と検査でだけ実行します。** 本番では実行しません。実行しようとしたら、
# その場で失敗させます。
#
# 実行 : bin/rails runner ../../scripts/ci/prepare_e2e_data.rb

# **本番では動かしません。** 記録を作る手順ですので、間違って本番へ向けたら止めます。
unless AppEnvironment.developer_shortcuts_allowed?
  raise "確認用の記録は、開発と検査でのみ用意します: #{AppEnvironment.current}" # 開発者向け
end

# 確認用の記録を組み立てます。
#
# **`.first` で拾いません。** 空のデータベースで実行しますので、
# 拾う相手が居ない場合はその場で失敗させます。
class E2eFixture
  X_USER_ID_KEY = 'DEVELOPMENT_AUTO_LOGIN_X_USER_ID'

  COMPOSITIONS = %w[subject_led environment_led abstract_background].freeze

  def call
    user = find_user!
    project = build_project(user)
    request = build_request(project)
    build_outputs(request)
    settle(user, request)

    request
  end

  private

  def find_user!
    x_user_id = ENV.fetch(X_USER_ID_KEY, nil)
    raise "#{X_USER_ID_KEY} が設定されていません。" if x_user_id.blank? # 開発者向け

    User.find_by!(x_user_id: x_user_id)
  end

  def build_project(user)
    Project.find_or_create_by!(user: user, industry: 'medical', style_family: 'photoreal') do |project|
      project.name = 'Aozora Dental'
      project.brand_settings = { Project::TONE_KEY => 'trust' }
    end
  end

  # **縮退で仕上げた記録です。** 一覧の「縮退」の印と、
  # 生成中の画面の「DEGRADED MODE」「NOT REFINED」を出すためです。
  def build_request(project)
    request = PromptRequest.create!(
      project: project,
      target_model: 'midjourney',
      inputs: inputs,
      status: PromptRequest::DRAFT
    )
    request.transition_to!(PromptRequest::QUEUED)
    request.transition_to!(PromptRequest::GENERATING)
    request.transition_to!(PromptRequest::DEGRADED_COMPLETED,
                           degraded: true,
                           dictionary_version: RuleDictionary.current!.version)
    request
  end

  def inputs
    {
      'industry' => 'medical',
      'style_family' => 'photoreal',
      'target_model' => 'midjourney',
      'brand_tone' => 'trust',
      'service_summary' => '「あおぞら歯科」という歯科医院です。',
      'copy_space_position' => 'left',
      'aspect_ratio' => '16:9'
    }
  end

  def build_outputs(request)
    COMPOSITIONS.each_with_index do |composition, index|
      PromptOutput.create!(
        prompt_request: request,
        variation_no: index + 1,
        composition_type: composition,
        main_prompt: main_prompt_for(composition),
        negative_prompt: 'text, watermark, extra fingers',
        parameters: { 'aspect_ratio' => '16:9', 'stylize' => 250 },
        art_direction_note: note.to_json
      )
    end
  end

  def main_prompt_for(composition)
    "A calm dental clinic interior, #{composition.tr('_', ' ')}, " \
      'photographed with a 35mm lens, clear copy space across the left third of the frame --ar 16:9'
  end

  # **文言は設定から引きます。** 画面が出す見出しと揃えるためです。
  def note
    {
      checkpoints: [
        { key: 'copy_space', heading: I18n.t('art_direction_note.headings.checkpoints'),
          text: '左 3 分の 1 に文字を置ける余白が空いていることを確かめます。' },
        { key: 'people', heading: I18n.t('art_direction_note.headings.checkpoints'),
          text: '人物の手指が破綻していないことを確かめます。' }
      ],
      adjustments: [
        { key: 'stylize', heading: I18n.t('art_direction_note.headings.adjustments'),
          text: '硬い印象が強い場合は、光をやわらげます。' }
      ],
      headings: {
        checkpoints: I18n.t('art_direction_note.headings.checkpoints'),
        adjustments: I18n.t('art_direction_note.headings.adjustments')
      }
    }
  end

  # **枠を確定させます。** 上限到達の確認は、確認の側で枠を使い切ります。
  # ここで予約を残すと、**その日の枠が最初から埋まった状態**になります。
  def settle(user, request)
    Quota::Reservation.reserve!(user: user, prompt_request: request)
    Quota::Reservation.settle!(request)
  end
end

request = E2eFixture.new.call
puts "確認用の記録を用意しました: prompt_request=#{request.id} status=#{request.status} 案=#{request.prompt_outputs.count}"
