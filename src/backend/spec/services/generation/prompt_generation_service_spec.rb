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

  # **段を外したら、テストが落ちます**（PR #163 のレビューより）。
  describe '工程の並び' do
    it '展開の前に当てる段を、一覧で持ちます' do
      expect(described_class::STEPS)
        .to eq(%i[proper_nouns style_spec copy_space anti_ai_rules])
    end

    # **日本語固有名詞の段**が働いていることを、素材で確かめます。
    it '日本語の名前を保ちます' do
      built = packages(service_summary: '「さくら堂」という店を営んでいます。')

      expect(built.first.draft.main_terms).to include(a_string_including('Sakuradou'))
    end

    # **アンチAIルック規則の段**が働いていることを、素材で確かめます。
    it '打ち消しの語を注入します' do
      expect(packages.first.draft.negative_terms).not_to be_empty
    end

    # **素材がそろってから当てます**（issue #161）。
    it '排除する語に当たった素材を落とします' do
      dictionary.update!(anti_ai_rules: { 'forbidden_terms' => ['sakuradou'],
                                          'negative_prompt_terms' => ['deformed hands'] })
      built = packages(service_summary: '「さくら堂」という店を営んでいます。')
      removed = built.first.draft.notes
                     .select { |note| note[:kind] == Generation::RuleEngine::REMOVED_NOTE_KIND }

      expect(removed).not_to be_empty
    end

    # **スタイル系統の仕様化の段**が働いていることを、控えで確かめます。
    it '撮影の指示を足します' do
      expect(packages.first.draft.main_terms).to include(a_string_including('lens'))
    end

    # **コピースペースの段**が働いていることを、素材で確かめます。
    it '文字を置く余白を確保します' do
      expect(packages.first.draft.main_terms).to include(a_string_including('copy space'))
    end
  end

  # **選ばれた生成 AI の記法で整えます**（requirements.md 4.1 の 7）。
  describe 'モデル別の整形' do
    Generation::InputChoices::TARGET_MODELS.each do |model|
      it "#{model}：貼り付けられる形を返します" do
        expect(packages(target_model: model)).to all(satisfy do |package|
          package.formatted.to_prompt.present?
        end)
      end

      # **日本語固有名詞は、そのまま残ることがあります**（requirements.md 4.1 の 6）。
      # 読みが決まらない名前を訳すと、別のお名前になります。
      it "#{model}：名前が無ければ日本語を含みません" do
        expect(packages(target_model: model)).to all(satisfy do |package|
          package.formatted.to_prompt.exclude?('櫻')
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

  # **撮影指示を欠く案は出力しません**（requirements.md 4.2）。
  describe '撮影の指示' do
    it 'すべての案が撮影の指示を持ちます' do
      expect(packages).to all(satisfy { |package| package.draft.main_terms.grep(/lens/).any? })
    end

    # **規則辞書の「排除する語」に当たると、指示ごと落ちます。**
    it '指示が落ちていれば出力しません' do
      dictionary.update!(anti_ai_rules: { 'forbidden_terms' => ['a 35mm lens'],
                                          'negative_prompt_terms' => ['deformed hands'] })

      expect { packages }.to raise_error(described_class::MissingSpecificationsError)
    end

    # **案ごとに外した指示は、控えからも外れます**（issue #50）。
    it '案ごとに外した指示では止まりません' do
      expect { packages }.not_to raise_error
    end
  end

  # **禁止入力は、クォータを使う前に見ます。**
  describe '禁止入力' do
    it '見つかれば出力しません' do
      expect { packages(service_summary: '他社のロゴを大きく掲載してください。') }
        .to raise_error(described_class::ForbiddenInputError)
    end

    it '理由を添えます' do
      expect { packages(service_summary: '他社のロゴを大きく掲載してください。') }
        .to raise_error(described_class::ForbiddenInputError) { |error| expect(error.reasons).to be_present }
    end

    # **形の誤りは、先に項目名を添えて返します。**
    # 検出は文章を舐めますので、長さの上限を通した文字列だけを渡します。
    it '形の誤りがあれば、そちらを先に返します' do
      expect { packages(industry: 'unknown', service_summary: '他社のロゴを大きく掲載してください。') }
        .to raise_error(Generation::InputNormalizer::InvalidInputError)
    end
  end

  describe '入力の誤り' do
    it '選べない値なら出力しません' do
      expect { packages(industry: 'unknown') }
        .to raise_error(Generation::InputNormalizer::InvalidInputError)
    end

    # **形・型・長さは、正規化が項目名を添えて検めます**（PR #163 のレビューより）。
    ['文字列です', [], 1, nil].each do |value|
      it "入力が「#{value.inspect}」なら、項目名を添えて失敗します" do
        expect { service.call(value) }
          .to raise_error(Generation::InputNormalizer::InvalidInputError) { |error|
            expect(error.errors.first[:field]).to be_present
          }
      end
    end

    it 'サービス概要が文字列でなければ、項目名を添えて失敗します' do
      expect { packages(service_summary: 123) }
        .to raise_error(Generation::InputNormalizer::InvalidInputError) { |error|
          expect(error.errors.pluck(:field)).to include(:service_summary)
        }
    end

    # **長さの上限を通していない文字列を、検出へ渡しません。**
    it '長すぎるサービス概要は、検出の前に止めます' do
      expect { packages(service_summary: 'あ' * 4000) }
        .to raise_error(Generation::InputNormalizer::InvalidInputError) { |error|
          expect(error.errors.pluck(:reason)).to include(:too_long)
        }
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
    it '案・整形の結果・ノート・縮退の印を持ちます' do
      expect(packages.first.to_h.keys)
        .to contain_exactly(:variation, :formatted, :note, :degraded)
    end

    # **縮退した案には印が残ります**（issue #53）。
    it '磨けなければ縮退の印が立ちます' do
      expect(packages).to all(be_degraded)
    end

    it '案の番号と構図の種別を引けます' do
      expect(packages.map(&:number)).to eq([1, 2, 3])
      expect(packages.map(&:composition_type))
        .to eq(%w[subject_led environment_led abstract_background])
    end
  end
end
