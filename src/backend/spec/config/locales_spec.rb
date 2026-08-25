# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '文言の定義' do
  it '日本語のみを提供します' do
    expect(I18n.available_locales).to eq([:ja])
  end

  it '既定の言語は日本語です' do
    expect(I18n.default_locale).to eq(:ja)
  end

  it '文言を取り出せます' do
    expect(I18n.t('errors.unauthorized.message')).to eq('ログインが必要です。')
  end

  it '見つからない場合は例外にします' do
    expect { I18n.t('errors.unauthorized.unknown') }
      .to raise_error(I18n::MissingTranslationData)
  end

  it 'すべての文言がですます調で終わります' do
    values = []
    collect = lambda do |node|
      case node
      when String then values << node
      when Hash then node.each_value { |v| collect.call(v) }
      end
    end
    collect.call(I18n.backend.send(:translations)[:ja])

    expect(values).not_to be_empty
    expect(values).to all(end_with('。'))
  end
end
