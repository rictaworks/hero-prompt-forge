# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Metrics::Recorder do
  # JST 03:00 を境界とするクォータ日です。
  let(:noon) { Time.zone.parse('2026-08-27 12:00:00 +09:00') }
  let(:before_reset) { Time.zone.parse('2026-08-28 02:59:00 +09:00') }
  let(:after_reset) { Time.zone.parse('2026-08-28 03:00:00 +09:00') }

  describe '.record' do
    it '軸と日で 1 行を作ります' do
      described_class.record(described_class::QUOTA_EXHAUSTED, now: noon)

      expect(MetricEvent.count).to eq(1)
    end

    it '同じ日に重ねると数え上げます' do
      3.times { described_class.record(described_class::QUOTA_EXHAUSTED, now: noon) }

      expect(MetricEvent.sole.count).to eq(3)
    end

    it '軸ごとに分けて数えます' do
      described_class.record(described_class::QUOTA_EXHAUSTED, now: noon)
      described_class.record(described_class::QUOTA_RECLAIMED, now: noon)

      expect(MetricEvent.count).to eq(2)
    end

    # **クォータ日は JST 03:00 を境界とします。**
    it '03:00 の前は前日として数えます' do
      described_class.record(described_class::QUOTA_EXHAUSTED, now: before_reset)

      expect(MetricEvent.sole.occurred_on).to eq(Date.new(2026, 8, 27))
    end

    it '03:00 からは当日として数えます' do
      described_class.record(described_class::QUOTA_EXHAUSTED, now: after_reset)

      expect(MetricEvent.sole.occurred_on).to eq(Date.new(2026, 8, 28))
    end

    # **個人を特定できる形で記録しません。**
    it '残すのは軸・日・件数だけです' do
      described_class.record(described_class::QUOTA_EXHAUSTED, now: noon)
      columns = MetricEvent.column_names - %w[id created_at updated_at]

      expect(columns).to contain_exactly('axis', 'occurred_on', 'count')
    end

    # **定義に無い軸を記録しません。**
    ['generation_count', '', nil, :quota_exhausted].each do |axis|
      it "「#{axis.inspect}」なら失敗します" do
        expect { described_class.record(axis, now: noon) }
          .to raise_error(described_class::UnknownAxisError)
      end
    end
  end

  describe '.total' do
    it '期間内の件数を返します' do
      2.times { described_class.record(described_class::QUOTA_EXHAUSTED, now: noon) }
      described_class.record(described_class::QUOTA_EXHAUSTED, now: after_reset)

      expect(described_class.total(described_class::QUOTA_EXHAUSTED,
                                   from: Date.new(2026, 8, 27), to: Date.new(2026, 8, 28)))
        .to eq(3)
    end

    it '期間の外は数えません' do
      described_class.record(described_class::QUOTA_EXHAUSTED, now: noon)

      expect(described_class.total(described_class::QUOTA_EXHAUSTED,
                                   from: Date.new(2026, 8, 28), to: Date.new(2026, 8, 29)))
        .to eq(0)
    end

    it '定義に無い軸なら失敗します' do
      expect { described_class.total('generation_count', from: Date.current, to: Date.current) }
        .to raise_error(described_class::UnknownAxisError)
    end
  end
end
