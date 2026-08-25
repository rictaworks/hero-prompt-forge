# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppEnvironment do
  describe ".current" do
    it "APP_ENV の値を返します" do
      allow(ENV).to receive(:fetch).with("APP_ENV", nil).and_return("test")

      expect(described_class.current).to eq("test")
    end

    it "未知の値なら例外にします" do
      allow(ENV).to receive(:fetch).with("APP_ENV", nil).and_return("staging")

      expect { described_class.current }
        .to raise_error(AppEnvironment::UnknownEnvironmentError, /staging/)
    end
  end

  describe ".developer_shortcuts_allowed?" do
    it "本番では必ず false を返します" do
      allow(ENV).to receive(:fetch).with("APP_ENV", nil).and_return("production")

      expect(described_class.developer_shortcuts_allowed?).to be(false)
    end

    it "開発環境では true を返します" do
      allow(ENV).to receive(:fetch).with("APP_ENV", nil).and_return("development")

      expect(described_class.developer_shortcuts_allowed?).to be(true)
    end
  end
end
