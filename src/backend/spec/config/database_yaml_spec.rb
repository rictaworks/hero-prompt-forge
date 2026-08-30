# frozen_string_literal: true

require 'rails_helper'
require 'active_support/configuration_file'

# database.yml が、本番の起動条件でも安全に読み込めることを確かめます（issue #190）。
#
# Rails は `config/database.yml` を読み込むとき、**有効な RAILS_ENV の節だけでなく、
# ファイル全体の ERB を先に評価**します（`ActiveSupport::ConfigurationFile.parse`。
# `bin/rails db:prepare` もこの経路を通ります）。そのため、本番で `DATABASE_URL`
# しか渡していなくても、`test:` 節の ERB は必ず走ります。
#
# `test:` 節が既定値を持たないと、`TEST_DATABASE_URL` を設定していない本番コンテナは、
# 起動のたびに `KeyError` で落ちます。**このテストは、実際に Rails が使う
# `ActiveSupport::ConfigurationFile.parse` を直接呼び、その落とし方を再現します。**
RSpec.describe 'database.yml' do
  def database_yaml_path
    Rails.root.join('config/database.yml')
  end

  # ENV を退避し、本番の起動条件（TEST_DATABASE_URL を持たない）へ切り替えます。
  def with_env(overrides)
    original = ENV.to_hash
    overrides.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    ENV.replace(original)
  end

  context 'TEST_DATABASE_URL を設定していないとき（本番の起動条件）' do
    it 'ファイル全体の読み込みで例外になりません' do
      with_env('TEST_DATABASE_URL' => nil, 'DATABASE_URL' => 'postgres://example/production_only') do
        expect { ActiveSupport::ConfigurationFile.parse(database_yaml_path) }.not_to raise_error
      end
    end

    it 'test 節は既定値の接続先を使います' do
      with_env('TEST_DATABASE_URL' => nil, 'DATABASE_URL' => 'postgres://example/production_only') do
        config = ActiveSupport::ConfigurationFile.parse(database_yaml_path)

        expect(config.dig('test', 'url')).to eq('postgresql://localhost/hero_prompt_forge_test')
      end
    end

    it '本番の項目は、渡した DATABASE_URL をそのまま使います（既定値を持ちません）' do
      with_env('TEST_DATABASE_URL' => nil, 'DATABASE_URL' => 'postgres://example/production_only') do
        config = ActiveSupport::ConfigurationFile.parse(database_yaml_path)

        expect(config.dig('production', 'url')).to eq('postgres://example/production_only')
      end
    end
  end

  context 'DATABASE_URL を設定していないとき' do
    # **本番の接続先には既定値を持たせません。** 気づかず既定値へつながると、
    # 本番のつもりで別のデータベースを操作してしまう恐れがあるためです。
    # 落ちる先は変えず、これまでどおり例外にします。
    it 'ファイル全体の読み込みが KeyError で失敗します' do
      with_env('TEST_DATABASE_URL' => 'postgres://example/test', 'DATABASE_URL' => nil) do
        expect { ActiveSupport::ConfigurationFile.parse(database_yaml_path) }.to raise_error(KeyError)
      end
    end
  end

  context 'TEST_DATABASE_URL を設定しているとき（従来どおりの動作）' do
    it '設定した接続先をそのまま使います' do
      with_env('TEST_DATABASE_URL' => 'postgres://example/explicit_test',
                'DATABASE_URL' => 'postgres://example/production_only') do
        config = ActiveSupport::ConfigurationFile.parse(database_yaml_path)

        expect(config.dig('test', 'url')).to eq('postgres://example/explicit_test')
      end
    end
  end
end
