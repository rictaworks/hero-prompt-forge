# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::PromptGenerationService do
  let(:anti_ai_rules) { InitialRuleDictionary.anti_ai_rules }

  let(:dictionary) do
    RuleDictionary.create!(version: 'vspec.assembly', anti_ai_rules: anti_ai_rules,
                           style_spec_rules: InitialRuleDictionary.style_spec_rules,
                           industry_defaults: InitialRuleDictionary.industry_defaults)
  end

  let(:service) { described_class.new(dictionary: dictionary) }

  # 余白の素材だけを落とす統合の段です。**ノートは残ります。**
  def stripping(resolver)
    allow(resolver).to receive(:resolve).and_wrap_original do |call, draft|
      resolved = call.call(draft)
      resolved.replace(main_terms: resolved.main_terms.grep_v(/copy space/))
    end
    resolver
  end

  # **`raw` という名前を使いません。** 画面の文字を安全と印づける仕組みと同じ名前です。
  def request_fields(**overrides)
    { industry: 'saas', style_family: 'photoreal', target_model: 'midjourney',
      brand_tone: 'trust', copy_space_position: 'left',
      aspect_ratio: '16:9' }.merge(overrides)
  end

  def packages(**overrides)
    service.call(request_fields(**overrides))
  end

  # **決まった順で呼びます**（requirements.md 4.1）。
  describe '組み立て' do
    it '3 案を返します' do
      expect(packages.size).to eq(3)
    end

    it '案ごとに整形の結果を持ちます' do
      expect(packages).to all(satisfy { |package| package.formatted.to_prompt.present? })
    end

    it '案ごとにアートディレクションノートを持ちます' do
      expect(packages).to all(satisfy { |package| package.note.checkpoints.any? })
    end

    it '案の印を持ちます' do
      expect(packages.map { |package| package.variation[:composition] })
        .to eq(%w[subject_led environment_led abstract_background])
    end

    # **各段が付けたノートを、順序どおりに引き継ぎます。**
    it '各段のノートを引き継ぎます' do
      kinds = packages.first.draft.notes.pluck(:kind)

      expect(kinds).to include(Generation::StyleSpec::SPECIFICATIONS_NOTE_KIND,
                               Generation::CopySpace::NOTE_KIND,
                               Generation::VariationExpander::NOTE_KIND,
                               Generation::ConflictResolver::TONE_NOTE_KIND)
    end

    it 'ノートの並びが工程の順です' do
      kinds = packages.first.draft.notes.pluck(:kind)

      expect(kinds.index(Generation::CopySpace::NOTE_KIND))
        .to be < kinds.index(Generation::ConflictResolver::TONE_NOTE_KIND)
    end
  end

  # **選ばれた生成 AI の記法で整えます**（requirements.md 4.1 の 7）。
  describe 'モデル別の整形' do
    Generation::InputChoices::TARGET_MODELS.each do |model|
      it "#{model}：貼り付けられる形を返します" do
        expect(packages(target_model: model)).to all(satisfy do |package|
          package.formatted.to_prompt.match?(/\A[^ぁ-んァ-ヶ一-龥]+\z/)
        end)
      end
    end
  end

  # **コピースペースを持たない案は出力しません**（requirements.md 4.2）。
  describe 'コピースペースの確保' do
    it 'すべての案が余白の指定を持ちます' do
      expect(packages).to all(satisfy { |package| Generation::CopySpace.reserved?(package.draft) })
    end

    # **確かめるのはノートではなく、実際の素材です。**
    it '素材が落ちていれば出力しません' do
      allow(Generation::ConflictResolver).to receive(:new).and_wrap_original do |original, **args|
        stripping(original.call(**args))
      end

      expect { packages }.to raise_error(described_class::MissingCopySpaceError)
    end
  end

  # **禁止入力は、正規化より先に見ます。**
  describe '禁止入力' do
    it '見つかれば出力しません' do
      expect { packages(service_summary: '他社のロゴを大きく掲載してください。') }
        .to raise_error(described_class::ForbiddenInputError)
    end

    it '理由を添えます' do
      expect { packages(service_summary: '他社のロゴを大きく掲載してください。') }
        .to raise_error(described_class::ForbiddenInputError) { |error| expect(error.reasons).to be_present }
    end

    it '権利に関わらない誤りより先に見ます' do
      expect { packages(industry: 'unknown', service_summary: '他社のロゴを大きく掲載してください。') }
        .to raise_error(described_class::ForbiddenInputError)
    end
  end

  describe '入力の誤り' do
    it '選べない値なら出力しません' do
      expect { packages(industry: 'unknown') }
        .to raise_error(Generation::InputNormalizer::InvalidInputError)
    end
  end

  # **規則辞書の版は、最初から最後まで 1 つです。**
  describe '規則辞書の版' do
    it '案ごとの下書きが同じ版を持ちます' do
      expect(packages).to all(satisfy { |package| package.draft.dictionary_version == 'vspec.assembly' })
    end
  end

  describe '想定外の入力' do
    it '規則辞書が無ければ組み立てられません' do
      expect { described_class.new(dictionary: nil) }
        .to raise_error(described_class::MissingDictionaryError)
    end
  end

  describe '受け渡しの形' do
    it '案・整形の結果・ノートを持ちます' do
      expect(packages.first.to_h.keys).to contain_exactly(:variation, :formatted, :note)
    end
  end
end
