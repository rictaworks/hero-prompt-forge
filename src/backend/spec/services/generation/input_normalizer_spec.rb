# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::InputNormalizer do
  let(:dictionary) do
    RuleDictionary.create!(
      version: 'vspec.normalizer',
      industry_defaults: {
        'saas' => { 'tone' => 'trust', 'style_family' => 'photoreal' },
        'beauty' => { 'tone' => 'premium', 'style_family' => 'photoreal' }
      }
    )
  end

  let(:normalizer) { described_class.new(dictionary: dictionary) }

  def given(**overrides)
    {
      industry: 'saas',
      style_family: 'photoreal',
      target_model: 'midjourney'
    }.merge(overrides)
  end

  describe '必須の項目' do
    it '3項目がそろえば正規化できます' do
      expect(normalizer.call(given)).to include(
        industry: 'saas', style_family: 'photoreal', target_model: 'midjourney'
      )
    end

    it '業種が無ければ失敗します' do
      expect { normalizer.call(given(industry: nil)) }
        .to raise_error(described_class::InvalidInputError) { |error|
          expect(error.errors).to include(field: :industry, reason: :missing)
        }
    end

    it 'スタイル系統が無ければ失敗します' do
      expect { normalizer.call(given(style_family: nil)) }
        .to raise_error(described_class::InvalidInputError)
    end

    it '生成モデルが無ければ失敗します' do
      expect { normalizer.call(given(target_model: nil)) }
        .to raise_error(described_class::InvalidInputError)
    end

    it '空文字は欠損として扱います' do
      expect { normalizer.call(given(industry: '   ')) }
        .to raise_error(described_class::InvalidInputError)
    end

    it '誤りをまとめて返します' do
      expect { normalizer.call(given(industry: nil, style_family: nil)) }
        .to raise_error(described_class::InvalidInputError) { |error|
          expect(error.errors.pluck(:field)).to contain_exactly(:industry, :style_family)
        }
    end
  end

  describe '選択肢の検査' do
    it '定義されていない業種は失敗します' do
      expect { normalizer.call(given(industry: 'unknown')) }
        .to raise_error(described_class::InvalidInputError)
    end

    it '定義されていないスタイル系統は失敗します' do
      expect { normalizer.call(given(style_family: 'watercolor')) }
        .to raise_error(described_class::InvalidInputError)
    end

    it '定義されていない生成モデルは失敗します' do
      expect { normalizer.call(given(target_model: 'unknown_model')) }
        .to raise_error(described_class::InvalidInputError)
    end
  end

  describe 'トーンの補完' do
    it '未指定なら業種の標準トーンを使います' do
      expect(normalizer.call(given)[:brand_tone]).to eq('trust')
    end

    it '業種ごとに標準トーンが変わります' do
      expect(normalizer.call(given(industry: 'beauty'))[:brand_tone]).to eq('premium')
    end

    it '指定があればそちらを使います' do
      expect(normalizer.call(given(brand_tone: 'minimal'))[:brand_tone]).to eq('minimal')
    end

    it '定義されていないトーンは失敗します' do
      expect { normalizer.call(given(brand_tone: 'mysterious')) }
        .to raise_error(described_class::InvalidInputError)
    end

    it '規則辞書に業種の既定値が無ければ失敗します' do
      empty = RuleDictionary.create!(version: 'vspec.empty', industry_defaults: {})

      expect { described_class.new(dictionary: empty).call(given) }.to raise_error(KeyError)
    end
  end

  describe '既定値の補完' do
    it 'コピースペースの既定は左です' do
      expect(normalizer.call(given)[:copy_space_position]).to eq('left')
    end

    it 'アスペクト比の既定は 16:9 です' do
      expect(normalizer.call(given)[:aspect_ratio]).to eq('16:9')
    end

    it '指定があればそちらを使います' do
      normalized = normalizer.call(given(copy_space_position: 'right', aspect_ratio: '21:9'))

      expect(normalized).to include(copy_space_position: 'right', aspect_ratio: '21:9')
    end

    it '定義されていないコピースペース位置は失敗します' do
      expect { normalizer.call(given(copy_space_position: 'top')) }
        .to raise_error(described_class::InvalidInputError)
    end

    it '定義されていないアスペクト比は失敗します' do
      expect { normalizer.call(given(aspect_ratio: '1:1')) }
        .to raise_error(described_class::InvalidInputError)
    end
  end

  describe 'ブランドカラー' do
    it '2色まで受け取ります' do
      expect(normalizer.call(given(brand_colors: %w[#123456 #abcdef]))[:brand_colors])
        .to eq(%w[#123456 #ABCDEF])
    end

    it '未指定なら空の配列です' do
      expect(normalizer.call(given)[:brand_colors]).to eq([])
    end

    it '3色以上は失敗します' do
      expect { normalizer.call(given(brand_colors: %w[#111111 #222222 #333333])) }
        .to raise_error(described_class::InvalidInputError)
    end

    it '形式が違えば失敗します' do
      expect { normalizer.call(given(brand_colors: ['blue'])) }
        .to raise_error(described_class::InvalidInputError)
    end

    it '大文字小文字を揃えます' do
      expect(normalizer.call(given(brand_colors: ['#aabbcc']))[:brand_colors]).to eq(['#AABBCC'])
    end
  end

  describe 'サービス概要' do
    it '前後の空白を取り除きます' do
      expect(normalizer.call(given(service_summary: '  焙煎したての珈琲を届けます  '))[:service_summary])
        .to eq('焙煎したての珈琲を届けます')
    end

    it '未指定なら空です' do
      expect(normalizer.call(given)[:service_summary]).to be_nil
    end

    it '長すぎれば失敗します' do
      expect { normalizer.call(given(service_summary: 'あ' * 1001)) }
        .to raise_error(described_class::InvalidInputError)
    end
  end

  describe '型が違う入力' do
    it 'サービス概要が文字列でなければ、項目を添えて失敗します' do
      expect { normalizer.call(given(service_summary: 123)) }
        .to raise_error(described_class::InvalidInputError) { |error|
          expect(error.errors).to include(field: :service_summary, reason: :invalid_type)
        }
    end

    it 'ブランドカラーが配列でなければ、項目を添えて失敗します' do
      expect { normalizer.call(given(brand_colors: { '0' => '#111111' })) }
        .to raise_error(described_class::InvalidInputError) { |error|
          expect(error.errors).to include(field: :brand_colors, reason: :invalid_type)
        }
    end

    it 'ブランドカラーの中身が文字列でなければ、項目を添えて失敗します' do
      expect { normalizer.call(given(brand_colors: [123_456])) }
        .to raise_error(described_class::InvalidInputError) { |error|
          expect(error.errors).to include(field: :brand_colors, reason: :invalid_type)
        }
    end

    it '業種が文字列でなければ、項目を添えて失敗します' do
      expect { normalizer.call(given(industry: 1)) }
        .to raise_error(described_class::InvalidInputError) { |error|
          expect(error.errors).to include(field: :industry, reason: :invalid_type)
        }
    end

    it '入力そのものが読み取れない形なら失敗します' do
      expect { normalizer.call(nil) }
        .to raise_error(described_class::InvalidInputError)
    end

    it '型の誤りでも素の NoMethodError にしません' do
      expect { normalizer.call(given(service_summary: 123)) }
        .to raise_error(described_class::InvalidInputError)
    end
  end

  describe '規則辞書の不備' do
    it '辞書が無ければ組み立てられません' do
      expect { described_class.new(dictionary: nil) }
        .to raise_error(described_class::MissingDictionaryError)
    end

    it '辞書の標準トーンが選択肢の外なら失敗します' do
      broken = RuleDictionary.create!(
        version: 'vspec.broken',
        industry_defaults: { 'saas' => { 'tone' => 'mysterious' } }
      )

      expect { described_class.new(dictionary: broken).call(given) }
        .to raise_error(described_class::InvalidDictionaryError)
    end

    it '利用者の入力の誤りを、辞書の不備より先に返します' do
      empty = RuleDictionary.create!(version: 'vspec.empty2', industry_defaults: {})

      expect { described_class.new(dictionary: empty).call(given(style_family: 'watercolor')) }
        .to raise_error(described_class::InvalidInputError)
    end
  end

  describe '一覧の持ち主' do
    it '業種の一覧をプロジェクトと共有します' do
      expect(described_class::INDUSTRIES).to equal(Project::INDUSTRIES)
    end

    it 'スタイル系統の一覧をプロジェクトと共有します' do
      expect(described_class::STYLE_FAMILIES).to equal(Project::STYLE_FAMILIES)
    end

    it '生成モデルの一覧を生成リクエストと共有します' do
      expect(described_class::TARGET_MODELS).to equal(PromptRequest::TARGET_MODELS)
    end
  end

  describe '選択肢の総当たり' do
    it 'すべての生成モデルを受け取れます' do
      described_class::TARGET_MODELS.each do |model|
        expect(normalizer.call(given(target_model: model))[:target_model]).to eq(model)
      end
    end

    it 'すべてのコピースペース位置を受け取れます' do
      described_class::COPY_SPACE_POSITIONS.each do |position|
        expect(normalizer.call(given(copy_space_position: position))[:copy_space_position])
          .to eq(position)
      end
    end

    it 'すべてのアスペクト比を受け取れます' do
      described_class::ASPECT_RATIOS.each do |ratio|
        expect(normalizer.call(given(aspect_ratio: ratio))[:aspect_ratio]).to eq(ratio)
      end
    end

    it 'すべてのスタイル系統を受け取れます' do
      described_class::STYLE_FAMILIES.each do |family|
        expect(normalizer.call(given(style_family: family))[:style_family]).to eq(family)
      end
    end
  end

  describe '同じ色の重ねがけ' do
    it '同じ色を2つ指定すると失敗します' do
      expect { normalizer.call(given(brand_colors: %w[#111111 #111111])) }
        .to raise_error(described_class::InvalidInputError) { |error|
          expect(error.errors).to include(field: :brand_colors, reason: :duplicated)
        }
    end

    it '大文字小文字が違うだけの重ねがけも失敗します' do
      expect { normalizer.call(given(brand_colors: %w[#aabbcc #AABBCC])) }
        .to raise_error(described_class::InvalidInputError)
    end
  end

  describe '受け取る形' do
    it '文字列の鍵でも受け取れます' do
      expect(normalizer.call('industry' => 'saas', 'style_family' => 'photoreal',
                             'target_model' => 'midjourney'))
        .to include(industry: 'saas')
    end

    it '知らない項目は捨てます' do
      expect(normalizer.call(given(unexpected: 'value'))).not_to have_key(:unexpected)
    end
  end
end
