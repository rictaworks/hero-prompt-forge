# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::LlmSettings do
  after { described_class.reset! }

  def with_definition(loaded)
    allow(YAML).to receive(:safe_load_file).and_return(loaded)
    described_class.reset!
  end

  def sound_definition
    { 'model' => 'gemini-2.5-flash-lite',
      'endpoint' => 'https://example.test/v1/models/%<model>s:generateContent',
      'instruction' => 'Refine these fragments.',
      'open_timeout_seconds' => 5,
      'read_timeout_seconds' => 20,
      'write_timeout_seconds' => 10,
      'max_output_tokens' => 1024,
      'temperature' => 0.2 }
  end

  def expect_rejected(broken)
    with_definition(broken)

    expect { described_class.load }.to raise_error(described_class::InvalidDefinitionError)
  end

  describe '初期の設定' do
    it '最安のモデルを選びます' do
      expect(described_class.load['model']).to eq('gemini-2.5-flash-lite')
    end

    it '暗号化された呼び出し先です' do
      expect(described_class.load['endpoint']).to start_with('https://')
    end

    # **API キーを設定へ書きません。**
    it '鍵を含みません' do
      expect(described_class.load.values.join).not_to include('API_KEY')
    end
  end

  describe '設定の検め' do
    it '設定が読めなければ失敗します' do
      expect_rejected('壊れています')
    end

    %w[model endpoint instruction].each do |key|
      it "#{key} が無ければ失敗します" do
        expect_rejected(sound_definition.except(key))
      end
    end

    %w[open_timeout_seconds read_timeout_seconds write_timeout_seconds max_output_tokens]
      .each do |key|
      it "#{key} が正の数でなければ失敗します" do
        expect_rejected(sound_definition.merge(key => 0))
      end
    end

    # **暗号化されていない呼び出し先を認めません。**
    it '暗号化されていない呼び出し先なら失敗します' do
      expect_rejected(sound_definition.merge('endpoint' => 'http://example.test/v1'))
    end

    it 'ばらつきの大きさが範囲の外なら失敗します' do
      expect_rejected(sound_definition.merge('temperature' => 3))
    end
  end
end
