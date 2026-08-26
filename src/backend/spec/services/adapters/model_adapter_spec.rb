# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Adapters::ModelAdapter do
  let(:main_terms) do
    ['a calm office', '35mm lens', 'clear copy space across the left third of the frame']
  end

  let(:negative_terms) { ['deformed hands', 'watermark'] }

  after { Adapters::AdapterRules.reset! }

  def draft_for(**overrides)
    terms = overrides.delete(:main_terms) || main_terms
    negatives = overrides.key?(:negative_terms) ? overrides.delete(:negative_terms) : negative_terms

    Generation::Draft.new(
      input: { aspect_ratio: '16:9', target_model: 'midjourney' }.merge(overrides),
      main_terms: terms, negative_terms: negatives
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

    # **例外に、利用者由来の値そのものを入れません。**
    it '例外に利用者の入力をそのまま含めません' do
      expect { described_class.for('社外秘の値') }
        .to raise_error(described_class::UnknownModelError, /String/)
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
          expect(adapter.format(draft_for).main_prompt.downcase).to include('35mm lens')
        end

        it 'コピースペースの指定を落としません' do
          expect(adapter.format(draft_for).main_prompt.downcase).to include('copy space')
        end

        it 'アスペクト比を伝えます' do
          formatted = adapter.format(draft_for)

          expect(formatted.parameters.values.join(' ') + formatted.main_prompt)
            .to include('16:9')
        end

        # **鍵の名前はモデル共通です。** 受け取る側が一様に扱えるようにします。
        it 'アスペクト比のパラメータを共通の名前で返します' do
          expect(adapter.format(draft_for).parameters[described_class::ASPECT_RATIO_PARAMETER])
            .to eq('16:9')
        end

        # **貼り付けられる最終形を、この層で決めきります。**
        it '貼り付けられる最終形を返します' do
          formatted = adapter.format(draft_for)

          expect(formatted.to_prompt).to include(formatted.main_prompt)
        end

        it '最終形に日本語を混ぜません' do
          expect(adapter.format(draft_for).to_prompt).not_to match(/[ぁ-んァ-ヶ一-龥]/)
        end

        it '日本語を混ぜません' do
          expect(adapter.format(draft_for).main_prompt).not_to match(/[ぁ-んァ-ヶ一-龥]/)
        end

        # **打ち消しが 1 件も無くても、壊れた形を出しません。**
        it '打ち消しが 1 件も無くても整形できます' do
          formatted = adapter.format(draft_for(negative_terms: []))

          expect(formatted.to_prompt).to be_present
        end

        it '打ち消しが 1 件も無ければ、打ち消しを持ちません' do
          expect(adapter.format(draft_for(negative_terms: [])).negative?).to be(false)
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

        # **コピースペースを持たない案を出しません**（requirements.md 4.2）。
        it 'コピースペースの指定が無ければ失敗します' do
          without = draft_for(main_terms: ['a calm office', '35mm lens'])

          expect { adapter.format(without) }
            .to raise_error(described_class::InvalidDraftError)
        end
      end
    end
  end

  # **打ち消しの欄の有無は、モデルによって違います。**
  describe '打ち消しの欄' do
    # **nano banana 系は欄を持ちません。** 会話文で指示する作りで、負の指定を
    # 渡す項目がありません（PR #154 のレビューより）。
    {
      'midjourney' => true,
      'dalle' => false,
      'stable_diffusion' => true,
      'nano_banana' => false
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
    %w[dalle nano_banana].each do |model|
      it "#{model}：本文に、打ち消しの言い回しを入れません" do
        formatted = described_class.for(model).format(draft_for)

        expect(formatted.main_prompt).not_to match(/(?<![a-z])(no|without|avoid) /)
      end

      it "#{model}：本文に、打ち消したい語を入れません" do
        formatted = described_class.for(model).format(draft_for)

        expect(formatted.main_prompt).not_to include('deformed hands')
      end

      it "#{model}：打ち消しの欄を空にせず、無いことを返します" do
        expect(described_class.for(model).format(draft_for).negative_prompt).to be_nil
      end
    end
  end

  describe 'Midjourney 系の記法' do
    let(:formatted) { described_class.for('midjourney').format(draft_for) }

    it '語をカンマで並べます' do
      expect(formatted.main_prompt).to include(', ')
    end

    # **パラメータは本文の最後に置きます。** 途中に置くと効きません。
    it 'パラメータを本文の末尾へ付けます' do
      expect(formatted.to_prompt).to end_with('--ar 16:9 --no deformed hands, watermark')
    end

    it '本文にはパラメータを含めません' do
      expect(formatted.main_prompt).not_to include('--ar')
    end

    it '打ち消しを二重に出しません' do
      expect(formatted.to_prompt.scan('deformed hands').size).to eq(1)
    end

    # **値の無い `--no` は受け付けられません。**
    it '打ち消しが 1 件も無ければ、打ち消しのパラメータを付けません' do
      bare = described_class.for('midjourney').format(draft_for(negative_terms: []))

      expect(bare.to_prompt).not_to include('--no')
    end

    it '打ち消しが 1 件も無くても、アスペクト比は付けます' do
      bare = described_class.for('midjourney').format(draft_for(negative_terms: []))

      expect(bare.to_prompt).to end_with('--ar 16:9')
    end
  end

  # **自然文で書くモデルの記法です。**
  describe '自然文で書くモデル' do
    %w[dalle nano_banana].each do |model|
      describe model do
        let(:formatted) { described_class.for(model).format(draft_for) }

        it '文として終わります' do
          expect(formatted.main_prompt).to end_with('.')
        end

        # **述語を持たない名詞句を並べません**（PR #154 のレビューより）。
        it '述語のある文で素材を述べます' do
          expect(formatted.main_prompt).to include('The image includes ')
        end

        it '素材を句点で分断しません' do
          expect(formatted.main_prompt).not_to include('. 35mm lens.')
        end

        it 'ヒーローイメージであることを最初に伝えます' do
          expect(formatted.main_prompt).to start_with('This is a hero image for a website')
        end

        it '最後の素材を and でつなぎます' do
          expect(formatted.main_prompt).to include(', and clear copy space')
        end

        # **アスペクト比を二度言いません。**
        it '素材が既にアスペクト比を述べていれば、重ねません' do
          told = draft_for(main_terms: main_terms + ['composed for a 16:9 wide crop'])
          prompt = described_class.for(model).format(told).main_prompt

          expect(prompt.scan('16:9').size).to eq(1)
        end

        it '素材が述べていなければ、先頭で伝えます' do
          expect(formatted.main_prompt).to include('composed for a 16:9 frame')
        end

        it '素材が 2 件なら読点を挟みません' do
          two = draft_for(main_terms: ['a calm office', 'clear copy space on the left'])
          prompt = described_class.for(model).format(two).main_prompt

          expect(prompt).to include('a calm office and clear copy space on the left.')
        end

        it '素材が 1 件ならそのまま述べます' do
          one = draft_for(main_terms: ['clear copy space on the left'])
          prompt = described_class.for(model).format(one).main_prompt

          expect(prompt).to include('The image includes clear copy space on the left.')
        end
      end
    end
  end

  describe 'DALL-E 系の記法' do
    let(:formatted) { described_class.for('dalle').format(draft_for) }

    it '打ち消しの欄を持ちません' do
      expect(formatted.negative_prompt).to be_nil
    end

    # **この呼び出しは比を受け付けません。画素で指定します。**
    it '画像の大きさを画素で渡します' do
      expect(formatted.parameters['size']).to match(/\A\d+x\d+\z/)
    end

    it '比をそのまま大きさへ渡しません' do
      expect(formatted.parameters['size']).not_to include(':')
    end

    Generation::InputChoices::ASPECT_RATIOS.each do |aspect_ratio|
      it "#{aspect_ratio}：大きさが決まります" do
        sized = described_class.for('dalle').format(draft_for(aspect_ratio: aspect_ratio))

        expect(sized.parameters['size']).to match(/\A\d+x\d+\z/)
      end
    end

    it '対応の無いアスペクト比なら失敗します' do
      expect { described_class.for('dalle').format(draft_for(aspect_ratio: '5:4')) }
        .to raise_error(described_class::InvalidDraftError)
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

    # **対象は、コピースペースの段が使う印そのものを見ます。**
    it '重み付けの印を、コピースペースの段と共有します' do
      expect(Adapters::StableDiffusionAdapter::EMPHASIS_MARK)
        .to eq(Generation::CopySpace::RESERVED_MARK)
    end

    # **記法で意味を持つ文字が混ざったら、その場で失敗させます。**
    ['clear copy space (left third) for a headline',
     'clear copy space: left third'].each do |term|
      it "「#{term}」なら失敗します" do
        unsafe = draft_for(main_terms: ['a calm office', term])

        expect { described_class.for('stable_diffusion').format(unsafe) }
          .to raise_error(described_class::UnsafeTermError)
      end
    end

    it '重みを付けない素材の括弧は許します' do
      safe = draft_for(main_terms: ['a calm office (seen from above)',
                                    'clear copy space on the left'])

      expect { described_class.for('stable_diffusion').format(safe) }.not_to raise_error
    end
  end

  describe '整形の結果' do
    it '本文・打ち消し・パラメータ・最終形を持ちます' do
      formatted = described_class.for('midjourney').format(draft_for)

      expect(formatted.to_h.keys)
        .to contain_exactly(:main_prompt, :negative_prompt, :parameters, :prompt)
    end
  end

  # **約束を実装していないアダプタは、その場で失敗させます。**
  describe '実装していない約束' do
    let(:bare) { described_class.new }

    it '本文の組み立てが未実装なら失敗します' do
      expect { bare.format(draft_for) }
        .to raise_error(described_class::AdapterNotImplementedError)
    end

    it '打ち消しの欄の有無が未実装なら失敗します' do
      expect { bare.negative_prompt? }
        .to raise_error(described_class::AdapterNotImplementedError)
    end

    # **Ruby が持つ同名の例外を覆い隠しません。**
    it '組み込みの例外と別の名前にします' do
      expect(described_class::AdapterNotImplementedError.ancestors)
        .not_to include(NotImplementedError)
    end
  end

  # **記法は人が編集するデータです。中身を信用しません。**
  describe '記法の検め' do
    def with_definition(loaded)
      allow(YAML).to receive(:safe_load_file).and_return(loaded)
      Adapters::AdapterRules.reset!
    end

    it '記法が読めなければ失敗します' do
      with_definition('壊れています')

      expect { described_class.for('midjourney').format(draft_for) }
        .to raise_error(Adapters::AdapterRules::InvalidDefinitionError)
    end

    it 'モデルの記法が無ければ失敗します' do
      with_definition({ 'dalle' => {} })

      expect { described_class.for('midjourney').format(draft_for) }
        .to raise_error(Adapters::AdapterRules::InvalidDefinitionError)
    end

    it '鍵が足りなければ失敗します' do
      with_definition({ 'midjourney' => { 'term_separator' => ', ' } })

      expect { described_class.for('midjourney').format(draft_for) }
        .to raise_error(Adapters::AdapterRules::InvalidDefinitionError)
    end

    it '日本語の記法は失敗します' do
      with_definition({ 'midjourney' => { 'term_separator' => '、',
                                          'aspect_ratio_parameter' => '--ar',
                                          'negative_parameter' => '--no' } })

      expect { described_class.for('midjourney').format(draft_for) }
        .to raise_error(Adapters::AdapterRules::InvalidDefinitionError)
    end
  end
end
