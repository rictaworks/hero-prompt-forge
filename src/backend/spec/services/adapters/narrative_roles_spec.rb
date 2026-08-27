# frozen_string_literal: true

require 'rails_helper'

# 素材の役割に応じた述語で、自然文を組み立てます（issue #156）。
#
# **実際の経路（規則の適用からバリエーションの展開まで）を通した下書きで
# 確かめます。** 手で組んだ下書きでは、控えに役割が入りません。
RSpec.describe '自然文の述語' do # rubocop:disable RSpec/DescribeClass
  let(:dictionary) do
    RuleDictionary.create!(
      version: 'vspec.roles',
      anti_ai_rules: InitialRuleDictionary.anti_ai_rules,
      style_spec_rules: InitialRuleDictionary.style_spec_rules,
      industry_defaults: InitialRuleDictionary.industry_defaults
    ).tap(&:publish!)
  end

  def inputs(**overrides)
    { industry: 'medical', style_family: 'photoreal', target_model: 'dalle',
      brand_tone: 'trust', brand_colors: ['#0E7C7B'],
      copy_space_position: 'left', aspect_ratio: '16:9' }.merge(overrides)
  end

  def packages(**overrides)
    Generation::PromptGenerationService.new(dictionary: dictionary).call(inputs(**overrides))
  end

  def main_prompt(**overrides)
    packages(**overrides).first.formatted.main_prompt
  end

  # 撮影の手段です。**画に写るものではありません。**
  def means
    ['a 35mm lens', 'a 24mm wide angle lens', 'a 50mm lens', 'an 85mm portrait lens',
     'soft key light from a north-facing window', 'bounced fill from a white wall',
     'subtle rim light separating the subject',
     'shallow depth of field on the subject plane']
  end

  # 「画に写っているもの」を述べる文です。
  def shows_sentence(prompt)
    prompt.split('. ').find { |sentence| sentence.start_with?('The image shows') }
  end

  %w[dalle nano_banana].each do |model|
    describe model do
      # **撮影の手段が、画に写るものとして述べられません**（受け入れ条件）。
      it '撮影の手段を「写っているもの」として述べません' do
        sentence = shows_sentence(main_prompt(target_model: model))

        expect(means.select { |item| sentence.to_s.include?(item) }).to be_empty
      end

      it '撮影の手段を、撮影の述語で述べます' do
        prompt = main_prompt(target_model: model)

        expect(prompt).to match(/The scene is photographed with [^.]*lens/)
      end

      it '被写界深度も、撮影の述語で述べます' do
        prompt = main_prompt(target_model: model)
        sentence = prompt.split('. ').find { |item| item.start_with?('The scene is photographed') }

        expect(sentence).to include('shallow depth of field on the subject plane')
      end

      it '構図の指定を、構図の述語で述べます' do
        prompt = main_prompt(target_model: model)

        sentence = prompt.split('. ').find { |item| item.start_with?('The composition keeps') }

        expect(sentence).to include('clear copy space across the left third of the frame')
      end

      it '配色を、配色の述語で述べます' do
        prompt = main_prompt(target_model: model)

        expect(prompt).to match(/The palette carries [^.]+/)
      end

      it '全体の雰囲気を、雰囲気の述語で述べます' do
        prompt = main_prompt(target_model: model)

        expect(prompt).to include('The scene carries an overall impression of calm reliability')
      end

      it '主役の置き方を、主役の述語で述べます' do
        prompt = main_prompt(target_model: model)

        expect(prompt).to match(/The image is led by [^.]+/)
      end

      # **描き方（イラスト・3D・抽象）も、描き方の述語で述べます。**
      # **ブランドカラーを指定しません。** 指定すると、スタイル系統の配色指定が
      # 弱められ、描き方の指示の数が変わります（issue #43）。
      it '描き方を、描き方の述語で述べます' do
        prompt = main_prompt(target_model: model, style_family: 'illustration',
                             industry: 'education', brand_colors: [])

        expect(prompt).to match(/The image is rendered with [^.]*linework/)
      end

      # **文として成立します。** 述語を持たない断片が並びません。
      it 'すべての文が述語を持つ形で始まります' do
        prompt = main_prompt(target_model: model)
        starts = prompt.split('. ').map { |sentence| sentence.split.first(3).join(' ') }

        expect(starts).to all(match(/\AThis is a|\AThe (image|scene|composition|palette|whole)/))
      end

      it '文の途中で句点が孤立しません' do
        prompt = main_prompt(target_model: model)

        expect(prompt).not_to include('. .')
      end

      it '文として終わります' do
        expect(main_prompt(target_model: model)).to end_with('.')
      end

      # **画面の比は、独立した 1 文のままです。**
      it '画面の比を 1 文で述べます' do
        expect(main_prompt(target_model: model)).to match(/The whole frame is [^.]+\.\z/)
      end

      # **素材を落としません。** どの素材も、いずれかの文の中に現れます。
      it '素材をひとつも落としません' do
        package = packages(target_model: model).first
        prompt = package.formatted.main_prompt
        aspect = package.draft.main_terms.select { |term| term.include?('composed for') }

        expect(package.draft.main_terms - aspect).to all(satisfy { |term| prompt.include?(term) })
      end

      # **どの案でも成立します。**
      it '3 案とも文として成立します' do
        prompts = packages(target_model: model).map { |item| item.formatted.main_prompt }

        expect(prompts).to all(end_with('.'))
      end

      it '3 案とも、撮影の手段を写っているものとして述べません' do
        sentences = packages(target_model: model)
                    .map { |item| shows_sentence(item.formatted.main_prompt) }

        found = sentences.flat_map { |item| means.select { |value| item.to_s.include?(value) } }

        expect(found).to be_empty
      end
    end
  end

  # **語を並べるモデルは、これまでどおりです。**
  %w[midjourney stable_diffusion].each do |model|
    describe model do
      it '素材を並べた形のままです' do
        expect(main_prompt(target_model: model)).to include(', ')
      end

      it '述語の文を混ぜません' do
        expect(main_prompt(target_model: model)).not_to include('The scene is photographed')
      end
    end
  end

  describe '役割の受け取り方' do
    # **素材の文字列を照合しません。控えから受け取ります**（受け入れ条件）。
    it '控えに役割が無ければ、既定の述語で述べます' do
      draft = Generation::Draft.new(
        input: { aspect_ratio: '16:9', copy_space_position: 'left' },
        main_terms: ['a 35mm lens', 'a calm office',
                     'clear copy space across the left third of the frame']
      )

      prompt = Adapters::ModelAdapter.for('dalle').format(draft).main_prompt

      expect(prompt).to include(
        'The image shows a 35mm lens, a calm office, and clear copy space across the left third of the frame.'
      )
    end

    # **控えに役割があれば、その述語で述べます。**
    it '控えの役割に従って述べます' do
      draft = Generation::Draft.new(
        input: { aspect_ratio: '16:9', copy_space_position: 'left' },
        main_terms: ['a 35mm lens', 'a calm office',
                     'clear copy space across the left third of the frame'],
        notes: [{ kind: :spec, roles: { 'lens_mm' => 'a 35mm lens' } }]
      )

      prompt = Adapters::ModelAdapter.for('dalle').format(draft).main_prompt

      expect(prompt).to include('The scene is photographed with a 35mm lens.')
    end

    it '役割のある素材を、既定の文から外します' do
      draft = Generation::Draft.new(
        input: { aspect_ratio: '16:9', copy_space_position: 'left' },
        main_terms: ['a 35mm lens', 'a calm office',
                     'clear copy space across the left third of the frame'],
        notes: [{ kind: :spec, roles: { 'lens_mm' => 'a 35mm lens' } }]
      )

      prompt = Adapters::ModelAdapter.for('dalle').format(draft).main_prompt

      expect(prompt).to include(
        'The image shows a calm office and clear copy space across the left third of the frame.'
      )
    end
  end

  describe '述語の定義' do
    after { Adapters::AdapterRules.reset! }

    # **人が編集するデータですので、中身を信用しません。**
    it '定義が無ければ失敗させます' do
      broken = Adapters::AdapterRules.send(:all)['dalle'].except('role_clauses')
      allow(YAML).to receive(:safe_load_file).and_return({ 'dalle' => broken })
      Adapters::AdapterRules.reset!

      expect { Adapters::ModelAdapter.for('dalle').format(sample_draft) }
        .to raise_error(Adapters::AdapterRules::InvalidDefinitionError)
    end

    it '差し込む場所が無ければ失敗させます' do
      broken = Adapters::AdapterRules.send(:all)['dalle']
                                     .merge('role_clauses' => [{ 'roles' => ['tone'],
                                                                 'template' => 'The scene' }])
      allow(YAML).to receive(:safe_load_file).and_return({ 'dalle' => broken })
      Adapters::AdapterRules.reset!

      expect { Adapters::ModelAdapter.for('dalle').format(sample_draft) }
        .to raise_error(Adapters::AdapterRules::InvalidDefinitionError)
    end

    it '役割の一覧が空なら失敗させます' do
      broken = Adapters::AdapterRules.send(:all)['dalle']
                                     .merge('role_clauses' => [{ 'roles' => [],
                                                                 'template' => '%<terms>s' }])
      allow(YAML).to receive(:safe_load_file).and_return({ 'dalle' => broken })
      Adapters::AdapterRules.reset!

      expect { Adapters::ModelAdapter.for('dalle').format(sample_draft) }
        .to raise_error(Adapters::AdapterRules::InvalidDefinitionError)
    end

    def sample_draft
      Generation::Draft.new(
        input: { aspect_ratio: '16:9', copy_space_position: 'left' },
        main_terms: ['a calm office',
                     'clear copy space across the left third of the frame']
      )
    end
  end
end
