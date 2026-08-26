# frozen_string_literal: true

module Admin
  # 規則辞書の編集です（requirements.md 4.3、7.2、issue #65）。
  #
  # **公開済みの版は書き換えません。** 生成に用いた版を後から追えるように
  # するためです。内容を変える場合は、**新しい版を作って公開します。**
  #
  # **無停止で更新できます**（requirements.md 7.2）。生成は、公開済みのうち
  # 最後に公開した版を、そのつど引きます。**公開した瞬間から次の生成に効きます。**
  #
  # **中身は JSON で受け取ります。** 規則辞書は入れ子の連想配列で、項目の数も
  # 業種の数も変わります。**画面で項目を固定すると、規則を足すたびに画面を
  # 直すことになります。**
  #
  # **読めない JSON は、その場で失敗させます。** 空の連想配列へ寄せると、
  # 規則の無い版が公開できてしまいます。
  class RuleDictionariesController < ApplicationController
    # 送られた中身が JSON として読めない場合に投げます。
    class InvalidJsonError < StandardError; end

    rescue_from InvalidJsonError, with: :render_invalid_json
    rescue_from ActiveRecord::RecordInvalid, with: :render_invalid_record
    rescue_from RuleDictionary::PublishedVersionError, with: :render_already_published

    # 中身の欄です。**画面と受け取りの両方から参照します。**
    CONTENT_FIELDS = %i[anti_ai_rules style_spec_rules industry_defaults].freeze

    def index
      @dictionaries = RuleDictionary.order(created_at: :desc)
      @current = RuleDictionary.current
    end

    def show
      @dictionary = RuleDictionary.find(params.expect(:id))
    end

    # **いま使う版を写して、新しい版の下書きにします。**
    # 白紙から書き起こすと、項目の写し忘れで撮影指示を欠いた版ができます。
    def new
      @source = RuleDictionary.current
      @dictionary = RuleDictionary.new(attributes_of(@source))
      @version = suggested_version
    end

    def create
      dictionary = RuleDictionary.create!(version: params.expect(:version), **submitted)

      redirect_to admin_rule_dictionary_path(dictionary),
                  notice: t('admin.rule_dictionaries.created')
    end

    # **公開した瞬間から、次の生成に効きます。**
    def publish
      dictionary = RuleDictionary.find(params.expect(:id))
      dictionary.publish!
      AdminAction.record!(actor: admin_actor, action: AdminAction::PUBLISHED_DICTIONARY,
                          details: { 'version' => dictionary.version })

      redirect_to admin_rule_dictionary_path(dictionary),
                  notice: t('admin.rule_dictionaries.published')
    end

    private

    # **写すのは中身だけです。** 版と公開の時刻は写しません。
    def attributes_of(source)
      return {} if source.nil?

      CONTENT_FIELDS.index_with { |field| source.public_send(field) }
    end

    def submitted
      CONTENT_FIELDS.index_with { |field| parsed(params.expect(field), field) }
    end

    # **読めない JSON は、その場で失敗させます。**
    def parsed(value, field)
      parsed = JSON.parse(value.to_s)
      raise InvalidJsonError, field.to_s unless parsed.is_a?(Hash) # 開発者向け

      parsed
    rescue JSON::ParserError
      raise InvalidJsonError, field.to_s # 開発者向け
    end

    # 次の版の名前の案です。**そのまま使う必要はありません。**
    def suggested_version
      today = Time.zone.today.strftime('v%Y.%m')
      taken = RuleDictionary.where('version LIKE ?', "#{today}.%").count

      "#{today}.#{taken + 1}"
    end

    def render_invalid_json(error)
      @source = RuleDictionary.current
      @dictionary = RuleDictionary.new
      @version = params[:version]
      @error = t('admin.rule_dictionaries.invalid_json', field: error.message)
      render :new, status: :unprocessable_content
    end

    def render_invalid_record(error)
      @source = RuleDictionary.current
      @dictionary = error.record
      @version = params[:version]
      @error = error.record.errors.full_messages.join(t('admin.labels.separator'))
      render :new, status: :unprocessable_content
    end

    def render_already_published(_error)
      redirect_to admin_rule_dictionaries_path,
                  alert: t('admin.rule_dictionaries.already_published')
    end
  end
end
