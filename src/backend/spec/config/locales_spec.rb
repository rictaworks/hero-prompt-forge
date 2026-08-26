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

  # **見出しと呼び名は、文ではありません。**
  # `headings`（見出し）と `labels`（呼び名・区切り）の下だけを、
  # 句点で終わらない文言の置き場とします。
  # 説明・案内・失敗の知らせは、いずれも文ですので句点で終わります。
  #
  # **`headings` を句点回避の置き場にしません**（PR #159 のレビューより）。
  # 見出しでないもの（役割の呼び名・語の区切り）は `labels` へ置きます。
  #
  # **`formats`（時刻・日付の書き方）も文ではありません。** Rails の標準の
  # 置き場ですので、そこへ置きます（PR #166 のレビューより）。**書式を
  # `labels` へ混ぜません。** 呼び名でも区切りでもないためです。
  def non_sentence_keys
    %i[headings labels formats]
  end

  def collect_sentences(node, inside_labels: false, into: [])
    case node
    when String then into << node unless inside_labels
    when Hash
      node.each do |key, value|
        collect_sentences(value, inside_labels: inside_labels || non_sentence_keys.include?(key),
                                 into: into)
      end
    end
    into
  end

  def collect_headings(node, inside_labels: false, into: [])
    case node
    when String then into << node if inside_labels
    when Hash
      node.each do |key, value|
        collect_headings(value, inside_labels: inside_labels || non_sentence_keys.include?(key),
                                into: into)
      end
    end
    into
  end

  it 'すべての文言がですます調で終わります' do
    sentences = collect_sentences(I18n.backend.send(:translations)[:ja])

    expect(sentences).not_to be_empty
    expect(sentences).to all(end_with('。'))
  end

  # **見出しの置き場を、句点を書かないための逃げ道にしません。**
  it '見出しは、見出しとして短いものだけです' do
    headings = collect_headings(I18n.backend.send(:translations)[:ja])

    expect(headings).not_to be_empty
    expect(headings).to all(satisfy { |value| value.length <= 30 })
  end

  it '見出しに句点を書きません' do
    headings = collect_headings(I18n.backend.send(:translations)[:ja])

    expect(headings).to all(satisfy { |value| value.exclude?('。') })
  end
end
