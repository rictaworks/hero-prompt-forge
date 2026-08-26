# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Adapters::ModelAdapter do
  let(:main_terms) do
    ['a calm office', '35mm lens', 'clear copy space across the left third of the frame']
  end

  let(:negative_terms) { ['deformed hands', 'watermark'] }

  def draft_for(**overrides)
    Generation::Draft.new(
      input: { aspect_ratio: '16:9', target_model: 'midjourney' }.merge(overrides),
      main_terms: main_terms, negative_terms: negative_terms
    )
  end

  describe '.for' do
    # **仕様が定める 4 系統をすべて持ちます。**
    Generation::InputChoices::TARGET_MODELS.each do |model|
      it "#{model}：アダプタを返します" do
        expect(described_class.for(model)).to be_a(described_class)
      end
    end

    it '対応しているモデルの一覧を返します' do
      expect(described_class.supported_models)
        .to match_array(Generation::InputChoices::TARGET_MODELS)
    end

    # **未対応のモデルは、その場で失敗させます。**
    # 既定のモデルへ寄せると、利用者が選んだのと違う記法の指示が出ます。
    ['unknown_model', '', nil, 'Midjourney', 123].each do |value|
      it "「#{value.inspect}」なら失敗します" do
        expect { described_class.for(value) }
          .to raise_error(described_class::UnknownModelError)
      end
    end
  end

  # **どのアダプタでも守る約束です。**
  describe '共通の約束' do
    Generation::InputChoices::TARGET_MODELS.each do |model|
      describe model do
        let(:adapter) { described_class.for(model) }

        it '本文を返します' do
          expect(adapter.format(draft_for).main_prompt).to be_present
        end

        it '素材をすべて含みます' do
          formatted = adapter.format(draft_for)

          expect(formatted.main_prompt.downcase).to include('35mm lens')
        end

        it 'コピースペースの指定を落としません' do
          expect(adapter.format(draft_for).main_prompt.downcase).to include('copy space')
        end

        it 'アスペクト比を伝えます' do
          formatted = adapter.format(draft_for)

          expect(formatted.parameters.values.join(' ') + formatted.main_prompt)
            .to include('16:9')
        end

        it '日本語を混ぜません' do
          expect(adapter.format(draft_for).main_prompt).not_to match(/[ぁ-んァ-ヶ一-龥]/)
        end

        it '素材が無ければ失敗します' do
          empty = Generation::Draft.new(input: { aspect_ratio: '16:9' })

          expect { adapter.format(empty) }
            .to raise_error(described_class::InvalidDraftError)
        end

        it '下書きでなければ失敗します' do
          expect { adapter.format('下書きではありません') }
            .to raise_error(described_class::InvalidDraftError)
        end

        it 'アスペクト比が無ければ失敗します' do
          without = Generation::Draft.new(input: {}, main_terms: main_terms)

          expect { adapter.format(without) }
            .to raise_error(described_class::InvalidDraftError)
        end
      end
    end
  end

  # **打ち消しの欄の有無は、モデルによって違います。**
  describe '打ち消しの欄' do
    {
      'midjourney' => true,
      'dalle' => false,
      'stable_diffusion' => true,
      'nano_banana' => true
    }.each do |model, has_negative|
      it "#{model}：#{has_negative ? '持ちます' : '持ちません'}" do
        expect(described_class.for(model).negative_prompt?).to be(has_negative)
      end

      it "#{model}：出力の形が、欄の有無と一致します" do
        formatted = described_class.for(model).format(draft_for)

        expect(formatted.negative?).to be(has_negative)
      end
    end

    # **打ち消しの欄を持たないモデルへ、打ち消しの言い回しを入れません。**
    # `no ...` と書くと、かえってその要素を呼び込むことが知られています。
    it '欄を持たないモデルの本文に、打ち消しの言い回しを入れません' do
      formatted = described_class.for('dalle').format(draft_for)

      expect(formatted.main_prompt).not_to match(/(?<![a-z])(no|without|avoid) /)
    end

    it '欄を持たないモデルの本文に、打ち消したい語を入れません' do
      formatted = described_class.for('dalle').format(draft_for)

      expect(formatted.main_prompt).not_to include('deformed hands')
    end
  end

  describe 'Midjourney 系の記法' do
    let(:formatted) { described_class.for('midjourney').format(draft_for) }

    it '語をカンマで並べます' do
      expect(formatted.main_prompt).to include(', ')
    end

    it 'アスペクト比をパラメータで渡します' do
      expect(formatted.parameters['--ar']).to eq('16:9')
    end

    it '打ち消しをパラメータで渡します' do
      expect(formatted.parameters['--no']).to include('deformed hands')
    end
  end

  describe 'DALL-E 系の記法' do
    let(:formatted) { described_class.for('dalle').format(draft_for) }

    it '自然文として組み立てます' do
      expect(formatted.main_prompt).to end_with('.')
    end

    it '文の先頭を大文字にします' do
      expect(formatted.main_prompt).to include('. A calm office.')
    end

    it 'ヒーローイメージであることを最初に伝えます' do
      expect(formatted.main_prompt).to start_with('A hero image for a website')
    end

    it '打ち消しの欄を持ちません' do
      expect(formatted.negative_prompt).to be_nil
    end
  end

  describe 'Stable Diffusion 系の記法' do
    let(:formatted) { described_class.for('stable_diffusion').format(draft_for) }

    # **重み付けは、いちばん大事な指示にだけ付けます。**
    it 'コピースペースの指定を強めます' do
      expect(formatted.main_prompt).to include('copy space across the left third of the frame:1.2')
    end

    it 'すべての指示に重みを付けません' do
      expect(formatted.main_prompt).to include('a calm office, 35mm lens')
    end

    it '打ち消しを別の欄で渡します' do
      expect(formatted.negative_prompt).to include('deformed hands')
    end

    it '打ち消しを本文へ入れません' do
      expect(formatted.main_prompt).not_to include('deformed hands')
    end
  end

  describe 'nano banana 系の記法' do
    let(:formatted) { described_class.for('nano_banana').format(draft_for) }

    it '自然文として組み立てます' do
      expect(formatted.main_prompt).to end_with('.')
    end

    it 'アスペクト比を本文でも伝えます' do
      expect(formatted.main_prompt).to include('16:9')
    end

    it '打ち消しを別の欄で渡します' do
      expect(formatted.negative_prompt).to include('watermark')
    end
  end

  describe '整形の結果' do
    it '本文・打ち消し・パラメータを持ちます' do
      formatted = described_class.for('midjourney').format(draft_for)

      expect(formatted.to_h.keys).to contain_exactly(:main_prompt, :negative_prompt, :parameters)
    end
  end

  # **約束を実装していないアダプタは、その場で失敗させます。**
  describe '実装していない約束' do
    let(:bare) { described_class.new }

    it '本文の組み立てが未実装なら失敗します' do
      expect { bare.format(draft_for) }.to raise_error(described_class::NotImplementedError)
    end

    it '打ち消しの欄の有無が未実装なら失敗します' do
      expect { bare.negative_prompt? }.to raise_error(described_class::NotImplementedError)
    end
  end
end
