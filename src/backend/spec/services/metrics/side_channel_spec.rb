# frozen_string_literal: true

require 'rails_helper'

# **測定の記録は、本業の結果を書き換えません**（PR #164 のレビューより）。
RSpec.describe Metrics::SideChannel do
  let(:noon) { Time.zone.parse('2026-08-27 12:00:00 +09:00') }

  # 記録の置き場が落ちている状態を作ります。
  def broken
    allow(Metrics::Recorder).to receive(:record)
      .and_raise(ActiveRecord::StatementInvalid, 'db down') # 開発者向け
  end

  describe '記録できる場合' do
    it '件数を数え上げます' do
      described_class.record(MetricEvent::QUOTA_EXHAUSTED, now: noon)

      expect(MetricEvent.sole.occurrences).to eq(1)
    end

    it '記録を返します' do
      expect(described_class.record(MetricEvent::QUOTA_EXHAUSTED, now: noon))
        .to be_a(MetricEvent)
    end
  end

  # **記録の置き場が落ちる形は、1 つではありません**（PR #164 の 2 回目の
  # レビューより）。`upsert` は書き込みを組み立てる前に列と一意索引を調べます
  # ので、表が無ければ `ArgumentError`、列の名前がずれていれば
  # `ActiveModel::UnknownAttributeError` になります。**種別で数え上げると、
  # 必ず漏れます。**
  [ActiveRecord::StatementInvalid, ArgumentError,
   ActiveModel::UnknownAttributeError, RuntimeError].each do |failure|
    describe "記録が #{failure} で落ちる場合" do
      before do
        allow(Metrics::Recorder).to receive(:record).and_raise(failure, 'broken') # 開発者向け
      end

      it '呼び出す側へ投げません' do
        expect { described_class.record(MetricEvent::QUOTA_EXHAUSTED, now: noon) }
          .not_to raise_error
      end

      it '失敗を残します' do
        allow(Rails.logger).to receive(:warn)

        described_class.record(MetricEvent::QUOTA_EXHAUSTED, now: noon)

        expect(Rails.logger).to have_received(:warn).with(/record_failed/)
      end
    end
  end

  describe '記録の置き場が落ちている場合' do
    before { broken }

    # **本業の失敗の種類を書き換えません。**
    it '呼び出す側へ投げません' do
      expect { described_class.record(MetricEvent::QUOTA_EXHAUSTED, now: noon) }
        .not_to raise_error
    end

    it '空を返します' do
      expect(described_class.record(MetricEvent::QUOTA_EXHAUSTED, now: noon)).to be_nil
    end

    # **握りつぶしません。** 失敗そのものを追える形で残します。
    #
    # **`warn` で残します。** 成功したときの「完了」の行に埋もれると、
    # 測定が落ちていることに気づけません。
    it '失敗を警告として残します' do
      allow(Rails.logger).to receive(:warn)

      described_class.record(MetricEvent::QUOTA_EXHAUSTED, now: noon)

      expect(Rails.logger).to have_received(:warn)
        .with(/record_failed axis=#{MetricEvent::QUOTA_EXHAUSTED} error=ActiveRecord::StatementInvalid/)
    end
  end

  # **書き間違いは受け止めません。** 定義に無い軸は、その場で失敗させます。
  describe '定義に無い軸の場合' do
    it '失敗させます' do
      expect { described_class.record('generation_count', now: noon) }
        .to raise_error(Metrics::Recorder::UnknownAxisError)
    end
  end
end
