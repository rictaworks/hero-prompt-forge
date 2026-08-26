# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::ForbiddenDetector do
  let(:detector) { described_class.new }

  def detect(summary)
    detector.call(service_summary: summary)
  end

  def kinds_in(result)
    result.reasons.map(&:kind)
  end

  describe '実在の人物' do
    it '有名人の名前を含むと差し戻します' do
      result = detect('大谷翔平さんのような選手に使ってほしいサービスです。')

      expect(result).to be_forbidden
      expect(kinds_in(result)).to include(:real_person)
    end

    it '姓名に敬称が付く言い回しを差し戻します' do
      result = detect('田中太郎さんの写真を大きく使います。')

      expect(result).to be_forbidden
      expect(kinds_in(result)).to include(:real_person)
    end

    it '実在の人物を使う意図の表現を差し戻します' do
      expect(detect('実在の人物をモデルにしてください。')).to be_forbidden
    end

    it '人物への言及が無ければ通します' do
      expect(detect('焙煎したての珈琲をお届けします。')).not_to be_forbidden
    end

    it '「お客さん」のような一般の言い回しは拾いません' do
      expect(detect('お客さんに落ち着いて過ごしていただける空間です。')).not_to be_forbidden
    end
  end

  describe '企業のロゴ・商標' do
    it 'ロゴへの言及を差し戻します' do
      result = detect('Apple のロゴを背景に入れてください。')

      expect(result).to be_forbidden
      expect(kinds_in(result)).to include(:brand_logo)
    end

    it '商標への言及を差し戻します' do
      expect(detect('スターバックスの店内のような雰囲気でお願いします。')).to be_forbidden
    end

    it '自社の説明は通します' do
      expect(detect('自社ブランドの落ち着いた雰囲気を出したいです。')).not_to be_forbidden
    end
  end

  describe '第三者の著作物' do
    it '作品名への言及を差し戻します' do
      result = detect('ジブリのような雰囲気のイラストにしてください。')

      expect(result).to be_forbidden
      expect(kinds_in(result)).to include(:third_party_work)
    end

    it '作家の作風への言及を差し戻します' do
      expect(detect('村上春樹の世界観でお願いします。')).to be_forbidden
    end
  end

  describe '差し戻しの内容' do
    it '種別と見つかった語を添えます' do
      result = detect('ジブリのような雰囲気にしてください。')

      expect(result.reasons.first.kind).to eq(:third_party_work)
      expect(result.reasons.first.matched).to eq('ジブリ')
    end

    it '利用者へ見せる文言をこの層で持ちません' do
      result = detect('ジブリのような雰囲気にしてください。')

      expect(result.reasons.first.to_h.keys).to contain_exactly(:kind, :matched)
    end

    it '複数の理由をまとめて返します' do
      result = detect('ジブリのような雰囲気で、Apple のロゴも入れてください。')

      expect(kinds_in(result).uniq).to include(:third_party_work, :brand_logo)
    end
  end

  describe '空の入力' do
    it '概要が無ければ通します' do
      expect(detect(nil)).not_to be_forbidden
    end

    it '空文字なら通します' do
      expect(detect('')).not_to be_forbidden
    end

    it '空白だけなら通します' do
      expect(detect('   ')).not_to be_forbidden
    end
  end

  describe '通した場合' do
    it '理由を持ちません' do
      expect(detect('焙煎したての珈琲をお届けします。').reasons).to be_empty
    end
  end

  describe '規則の読み込み' do
    it '定義ファイルから読み込みます' do
      expect(described_class.load_rules).to be_present
    end

    it '規則の定義が見つからなければ失敗させます' do
      expect { described_class.load_rules(path: 'config/locales/ja.yml') }
        .to raise_error(described_class::InvalidRuleError)
    end
  end
end
