# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Quota::QuotaDay do
  def jst(text)
    Time.find_zone!('Asia/Tokyo').parse(text)
  end

  describe '.of' do
    it '朝 03:00 はその日のクォータ日です' do
      expect(described_class.of(jst('2026-08-25 03:00:00'))).to eq(Date.new(2026, 8, 25))
    end

    it '朝 02:59 は前日のクォータ日です' do
      expect(described_class.of(jst('2026-08-25 02:59:59'))).to eq(Date.new(2026, 8, 24))
    end

    it '深夜 00:00 は前日のクォータ日です' do
      expect(described_class.of(jst('2026-08-25 00:00:00'))).to eq(Date.new(2026, 8, 24))
    end

    it '正午はその日のクォータ日です' do
      expect(described_class.of(jst('2026-08-25 12:00:00'))).to eq(Date.new(2026, 8, 25))
    end

    it '23:59 はその日のクォータ日です' do
      expect(described_class.of(jst('2026-08-25 23:59:59'))).to eq(Date.new(2026, 8, 25))
    end

    it '月をまたぐ境界でも正しく求まります' do
      expect(described_class.of(jst('2026-09-01 02:00:00'))).to eq(Date.new(2026, 8, 31))
    end

    it '年をまたぐ境界でも正しく求まります' do
      expect(described_class.of(jst('2027-01-01 01:00:00'))).to eq(Date.new(2026, 12, 31))
    end
  end

  describe '別の時間帯で与えた場合' do
    it '協定世界時で与えても日本時間で判断します' do
      # 2026-08-24 18:00 UTC は 2026-08-25 03:00 JST です。
      expect(described_class.of(Time.utc(2026, 8, 24, 18, 0, 0))).to eq(Date.new(2026, 8, 25))
    end

    it '協定世界時の 17:59 は前日のクォータ日です' do
      # 2026-08-24 17:59 UTC は 2026-08-25 02:59 JST です。
      expect(described_class.of(Time.utc(2026, 8, 24, 17, 59, 0))).to eq(Date.new(2026, 8, 24))
    end

    it 'アプリの既定の時間帯に左右されません' do
      Time.use_zone('UTC') do
        expect(described_class.of(jst('2026-08-25 02:00:00'))).to eq(Date.new(2026, 8, 24))
      end
    end
  end

  describe '.reset_at' do
    it '翌日の 03:00 を返します' do
      expect(described_class.reset_at(Date.new(2026, 8, 25)))
        .to eq(jst('2026-08-26 03:00:00'))
    end

    it '月末のクォータ日でも翌月の初日を返します' do
      expect(described_class.reset_at(Date.new(2026, 8, 31)))
        .to eq(jst('2026-09-01 03:00:00'))
    end
  end

  describe '.start_at' do
    it 'その日の 03:00 を返します' do
      expect(described_class.start_at(Date.new(2026, 8, 25)))
        .to eq(jst('2026-08-25 03:00:00'))
    end
  end

  describe '.seconds_until_reset' do
    it '残りの秒数を返します' do
      expect(described_class.seconds_until_reset(jst('2026-08-26 02:00:00')))
        .to eq(3600)
    end

    it '境界の直後は約24時間です' do
      expect(described_class.seconds_until_reset(jst('2026-08-25 03:00:00')))
        .to eq(86_400)
    end
  end

  describe '受け取る値の取り違え' do
    it '.of に日付を渡すと失敗します' do
      expect { described_class.of(Date.new(2026, 8, 25)) }
        .to raise_error(ArgumentError)
    end

    it '.start_at に時刻を渡すと失敗します' do
      expect { described_class.start_at(jst('2026-08-25 01:00:00')) }
        .to raise_error(ArgumentError)
    end

    it '.reset_at に時刻を渡すと失敗します' do
      expect { described_class.reset_at(jst('2026-08-25 01:00:00')) }
        .to raise_error(ArgumentError)
    end

    it '.seconds_until_reset に日付を渡すと失敗します' do
      expect { described_class.seconds_until_reset(Date.new(2026, 8, 25)) }
        .to raise_error(ArgumentError)
    end

    it '文字列を渡すと失敗します' do
      expect { described_class.of('2026-08-25 03:00:00') }
        .to raise_error(ArgumentError)
    end
  end

  describe '一日の長さ' do
    it 'クォータ日の始まりと終わりは24時間離れています' do
      day = Date.new(2026, 8, 25)

      expect(described_class.reset_at(day) - described_class.start_at(day)).to eq(86_400)
    end
  end
end
