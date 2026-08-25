# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Trace do
  let(:logger) { instance_spy(Logger) }

  before { allow(Rails).to receive(:logger).and_return(logger) }

  it '処理の開始と完了を記録します' do
    described_class.step('生成', request_id: 1) { :ok }

    expect(logger).to have_received(:info).with(/\[trace\] 生成 request_id=1/)
    expect(logger).to have_received(:info).with(/\[trace\] 生成 完了 request_id=1/)
  end

  it '戻り値をそのまま返します' do
    expect(described_class.step('生成') { :value }).to eq(:value)
  end

  it '例外を記録したうえで投げ直します' do
    expect { described_class.step('生成', request_id: 2) { raise ArgumentError, '壊れています' } }
      .to raise_error(ArgumentError, '壊れています')

    expect(logger).to have_received(:error)
      .with(/\[trace\] 生成 失敗 request_id=2 error=ArgumentError: 壊れています/)
  end

  it '例外を握りつぶしません' do
    expect { described_class.step('生成') { raise '失敗' } }.to raise_error(RuntimeError)
  end
end
