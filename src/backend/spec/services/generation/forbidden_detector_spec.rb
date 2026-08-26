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
      expect(detect('スターバックスのような雰囲気でお願いします。')).to be_forbidden
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

    it '直し方を引くための鍵を添えます' do
      result = detect('ジブリのような雰囲気にしてください。')

      expect(result.reasons.first.suggestion_key).to eq(:describe_style_by_attribute)
    end

    it '種別ごとに直し方の鍵が変わります' do
      result = detect('Apple のロゴを背景に入れてください。')

      expect(result.reasons.first.suggestion_key).to eq(:remove_third_party_mark)
    end

    it '利用者へ見せる文言をこの層で持ちません' do
      result = detect('ジブリのような雰囲気にしてください。')

      expect(result.reasons.first.to_h.keys)
        .to contain_exactly(:kind, :matched, :suggestion_key)
    end

    it '複数の理由をまとめて返します' do
      result = detect('ジブリのような雰囲気で、Apple のロゴも入れてください。')

      expect(kinds_in(result).uniq).to include(:third_party_work, :brand_logo)
    end
  end

  # 権利の問題と関係のない、ごく普通のサービス概要です。
  # **これらを止めてしまうと、利用者が生成をお申し込みになれません。**
  # requirements.md 4.1 の 10 業種について、代表的な言い回しを並べています。
  describe '通してよい文章' do
    ordinary = {
      'SaaS' => [
        '個人事業主様の請求書作成を支援します。',
        'Google カレンダーと双方向で同期できます。',
        'Microsoft 365 の導入支援を行っています。'
      ],
      '飲食' => ['焙煎したての珈琲をお届けします。'],
      '医療' => [
        '訪問看護でご利用者様のご自宅へ伺います。',
        '地域の皆様に信頼される歯科医院です。'
      ],
      '教育' => ['受験生の保護者様との面談を大切にしています。'],
      '不動産' => [
        'オーナー様の賃貸経営をまるごと代行します。',
        '入居者様の困りごとに24時間で応じます。'
      ],
      '製造' => [
        '創業70年、代表取締役社長が現場に立つ町工場です。',
        'トヨタ自動車の下請けとして精密部品を作っています。'
      ],
      '士業' => [
        '顧問先様の決算を伴走して支援します。',
        'お客様の課題に寄り添う士業事務所です。',
        '代表者氏名を大きく載せない構図でお願いします。'
      ],
      'EC' => [
        'ワンピースとブラウスを扱うアパレルの通販です。',
        'Amazon と自社サイトの在庫を一元管理します。'
      ],
      '美容' => ['施術者と担当者様が一緒に仕上がりを決めます。'],
      'その他' => [
        'ロゴを配置できる余白を左に確保してください。',
        '自社ロゴを置く余白を左に空けてください。',
        '名刺やロゴの制作を承ります。',
        '監督が選手を指導する少年野球の教室です。',
        '取締役会の様子を落ち着いた色調で表現したいです。'
      ]
    }

    ordinary.each do |industry, texts|
      texts.each do |text|
        it "#{industry}：「#{text}」を止めません" do
          expect(detect(text)).not_to be_forbidden
        end
      end
    end
  end

  # **一覧に載せていない語**を含む言い回しです。語彙ではなく語の形で見分けて
  # いることを確かめます。ここが通らないと、職種名を足し続ける保守に戻ります。
  describe '一覧に無い職種に敬称が付く言い回し' do
    [
      '美容師さんが担当します。',
      '税理士さんに相談できます。',
      '看護師さんが常駐します。',
      '調理師さんが仕込みをします。',
      '検査員さんが確認します。',
      '管理人さんが常駐します。',
      'カメラマンさんが撮影します。',
      'ネイリストさんの手元を写します。',
      'ドライバーさんの休憩室です。',
      '配達員さんが笑顔で届けます。'
    ].each do |text|
      it "「#{text}」を止めません" do
        expect(detect(text)).not_to be_forbidden
      end
    end
  end

  describe '自分のものを指す所有格とロゴ' do
    [
      'お客様のロゴを看板に反映します。',
      '事務所のロゴを右下に小さく置きます。',
      'ブランドのロゴを中央に配置してください。',
      'チームのロゴを制作するデザイン会社です。',
      '学校のロゴを校舎の壁に入れます。'
    ].each do |text|
      it "「#{text}」を止めません" do
        expect(detect(text)).not_to be_forbidden
      end
    end
  end

  describe '人物と関係のない「実在」' do
    [
      '実在する当院の外観写真を掲載しています。',
      '実在の店舗を撮影した写真のような質感にします。',
      '実在する工場の設備をそのまま写します。'
    ].each do |text|
      it "「#{text}」を止めません" do
        expect(detect(text)).not_to be_forbidden
      end
    end
  end

  # **見送る言い回しを先に書けば迂回できる、という状態を作りません。**
  describe '見送る言い回しが先にある場合' do
    it '自分のロゴを先に書いても、他社のロゴを見つけます' do
      result = detect('自社のロゴと他社のロゴを並べた構図にしたいです。')

      expect(result).to be_forbidden
      expect(kinds_in(result)).to include(:brand_logo)
    end

    it '職種の呼び方を先に書いても、人名を見つけます' do
      result = detect('担当者さんと山田太郎さんが対応します。')

      expect(result).to be_forbidden
      expect(kinds_in(result)).to include(:real_person)
    end
  end

  # **複数の言及があれば、そのすべてをお伝えします。**
  # 1件だけ返すと、先に書かれたお名前を直すべきだと利用者が気づけません。
  describe '同じ種別の言及が複数ある場合' do
    it '2名のお名前をどちらも返します' do
      result = detect('山田太郎さんと鈴木花子さんの写真を使います。')

      expect(result.reasons.map(&:matched)).to contain_exactly('山田太郎さん', '鈴木花子さん')
    end

    it '3名のお名前をすべて返します' do
      result = detect('佐藤一郎さん、高橋二郎さん、渡辺三郎さんを並べます。')

      expect(result.reasons.size).to eq(3)
    end

    it '記録の件数も実際の件数と揃います' do
      allow(Trace).to receive(:step).and_call_original

      detect('山田太郎さんと鈴木花子さんと佐藤次郎さんの3名を並べます。')

      expect(Trace).to have_received(:step) { |_name, context|
        expect(context[:count]).to eq(3)
      }
    end

    it '同じ言及に2つの規則が当たっても、1件にまとめます' do
      result = detect('大谷翔平さんのような選手に使ってほしいです。')

      expect(result.reasons.map(&:matched)).to eq(['大谷翔平さん'])
    end
  end

  # 一覧に無い役職の語尾です。語の形で見分けていることを確かめます。
  describe '一覧に無い役職の語尾' do
    [
      '協力会社さんとの情報共有を一本化します。',
      '取引先さんへの請求を自動で作成します。',
      '仕入先さんとの信頼で成り立つ料理です。',
      '常連客さんに支えられて30年になります。',
      '宮大工さんが建てた店舗が自慢です。',
      '協力工場さんと歩んで50年です。',
      '新郎新婦さんの門出を彩ります。',
      '警察官さんの立ち会いのもと撮影します。'
    ].each do |text|
      it "「#{text}」を止めません" do
        expect(detect(text)).not_to be_forbidden
      end
    end
  end

  # 「実在」に続く語が人を指さない場合です。
  describe '人を指さない「実在」' do
    [
      '実在する法人のみが登録できる仕組みです。',
      '実在の求人情報だけを掲載します。',
      '実在の店舗の見え方を再現します。',
      '実在する会社の考え方を伝えます。'
    ].each do |text|
      it "「#{text}」を止めません" do
        expect(detect(text)).not_to be_forbidden
      end
    end
  end

  # **商標の調査・出願は士業の中核業務です。** 業種の一覧にも入っています。
  describe '商標を業務として扱う言い回し' do
    [
      '他社の商標調査を代行します。',
      '第三者の商標を侵害しないか確認します。',
      '別のロゴ案もあわせてご提案します。',
      '商標登録の出願をお手伝いします。'
    ].each do |text|
      it "「#{text}」を止めません" do
        expect(detect(text)).not_to be_forbidden
      end
    end

    it '画面へ置く意図があれば止めます' do
      expect(detect('他社のロゴを載せたいです。')).to be_forbidden
    end
  end

  describe '理由の重なり' do
    it '同じ内容の理由を重ねて返しません' do
      result = detect('Apple のロゴを背景に入れてください。')

      expect(result.reasons.map(&:to_h).uniq.size).to eq(result.reasons.size)
    end
  end

  describe '記録に残す内容' do
    it '見つかった語を記録へ残しません' do
      allow(Trace).to receive(:step).and_call_original

      detect('田中太郎さんの写真を使います。')

      expect(Trace).to have_received(:step)
        .with('generation.forbidden_detected', hash_including(:kinds, :count))
    end

    it '種別と件数だけを残します' do
      allow(Trace).to receive(:step).and_call_original

      detect('田中太郎さんの写真を使います。')

      expect(Trace).to have_received(:step) { |_name, context|
        expect(context.keys).to contain_exactly(:kinds, :count)
      }
    end
  end

  # app-ui/degraded.html の差し戻し画面のモックが掲げる例文です。
  # モックは理由を2行示しますので、2種別を返せる必要があります。
  describe '差し戻し画面のモックの例文' do
    let(:mock_text) do
      '港区の法律事務所。実在弁護士の氏名を前面に出し、他社事務所のロゴと並べた構図にしたい。'
    end

    it '差し戻します' do
      expect(detect(mock_text)).to be_forbidden
    end

    it '実在の人物への言及を見つけます' do
      expect(kinds_in(detect(mock_text))).to include(:real_person)
    end

    it '他社のロゴへの言及を見つけます' do
      expect(kinds_in(detect(mock_text))).to include(:brand_logo)
    end

    it '2種別の理由を返します' do
      expect(kinds_in(detect(mock_text)).uniq.size).to eq(2)
    end
  end

  describe '文字列でない入力' do
    it '数値を文字列へ直さずに失敗させます' do
      expect { detect(123) }.to raise_error(described_class::InvalidInputError)
    end

    it '配列を文字列へ直さずに失敗させます' do
      expect { detect(['ジブリ']) }.to raise_error(described_class::InvalidInputError)
    end

    it '連想配列を文字列へ直さずに失敗させます' do
      expect { detect({ a: 1 }) }.to raise_error(described_class::InvalidInputError)
    end

    it '記号を文字列へ直さずに失敗させます' do
      expect { detect(:ジブリ) }.to raise_error(described_class::InvalidInputError)
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

    it '規則の鍵が無ければ失敗させます' do
      expect { described_class.load_rules(path: 'spec/fixtures/forbidden_inputs/no_rules_key.yml') }
        .to raise_error(described_class::InvalidRuleError)
    end

    it '規則が空なら失敗させます。空で素通しさせません' do
      expect { described_class.load_rules(path: 'spec/fixtures/forbidden_inputs/empty_rules.yml') }
        .to raise_error(described_class::InvalidRuleError)
    end

    it '検出の語が空なら失敗させます。空で素通しさせません' do
      expect do
        described_class.load_rules(path: 'spec/fixtures/forbidden_inputs/empty_patterns.yml')
      end.to raise_error(described_class::InvalidRuleError)
    end

    it '定義の形が違えば失敗させます' do
      expect { described_class.load_rules(path: 'spec/fixtures/forbidden_inputs/not_a_hash.yml') }
        .to raise_error(described_class::InvalidRuleError)
    end

    it 'すべての規則が直し方の鍵を持ちます' do
      expect(described_class.load_rules).to all(include(:suggestion_key))
    end

    it '定義ファイルが無ければ、読み込みの失敗として同じ型で返します' do
      expect { described_class.load_rules(path: 'config/does_not_exist.yml') }
        .to raise_error(described_class::InvalidRuleError)
    end
  end
end
