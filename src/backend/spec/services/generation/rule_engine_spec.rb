# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::RuleEngine do
  let(:dictionary) do
    RuleDictionary.create!(
      version: 'vspec.rules',
      anti_ai_rules: {
        'forbidden_terms' => ['purple to teal gradient', 'floating 3d shapes'],
        'negative_prompt_terms' => %w[oversaturation deformed_hands],
        'avoided_compositions' => ['large frontal face close-up']
      }
    )
  end

  let(:engine) { described_class.new(dictionary: dictionary) }
  let(:input) { { industry: 'saas', style_family: 'photoreal', target_model: 'midjourney' } }

  describe '#start' do
    it '入力を持つ下書きを起こします' do
      expect(engine.start(input).input).to eq(input)
    end

    it '規則辞書の版を記録します' do
      expect(engine.start(input).dictionary_version).to eq('vspec.rules')
    end

    it '素材は空から始まります' do
      draft = engine.start(input)

      expect(draft.main_terms).to be_empty
      expect(draft.negative_terms).to be_empty
    end
  end

  describe '#apply' do
    def applied(main_terms)
      engine.apply(engine.start(input).add(main_terms: main_terms))
    end

    it '排除する語をメインプロンプトから取り除きます' do
      draft = applied(['a calm office', 'purple to teal gradient'])

      expect(draft.main_terms).to eq(['a calm office'])
    end

    it '語を含む言い回しも取り除きます' do
      draft = applied(['purple to teal gradient background'])

      expect(draft.main_terms).to be_empty
    end

    it '排除する語が無ければそのまま残します' do
      draft = applied(['a calm office', 'soft window light'])

      expect(draft.main_terms).to eq(['a calm office', 'soft window light'])
    end

    it '注入する語をネガティブプロンプトへ入れます' do
      expect(applied(['a calm office']).negative_terms)
        .to include('oversaturation', 'deformed_hands')
    end

    it '注入する語は重ねません' do
      draft = engine.apply(engine.apply(engine.start(input).add(main_terms: ['a calm office'])))

      expect(draft.negative_terms.count('oversaturation')).to eq(1)
    end

    it '取り除いた素材をノートへ残します' do
      draft = applied(['purple to teal gradient'])

      expect(draft.notes.first[:term]).to eq('purple to teal gradient')
    end

    it '当たった語をノートへ残します' do
      draft = applied(['soft purple to teal gradient in the background'])

      expect(draft.notes.first[:matched]).to eq('purple to teal gradient')
    end

    it '取り除いた理由が種別で分かります' do
      draft = applied(['purple to teal gradient'])

      expect(draft.notes.first[:kind]).to eq(described_class::REMOVED_NOTE_KIND)
    end

    it '取り除いていなければノートを増やしません' do
      expect(applied(['a calm office']).notes).to be_empty
    end

    it '規則辞書の版を記録します' do
      expect(applied(['a calm office']).dictionary_version).to eq('vspec.rules')
    end

    it '入力はそのまま持ち越します' do
      expect(applied(['a calm office']).input).to eq(input)
    end
  end

  # **同じ語の別の書き方を取りこぼしません。**
  # 大文字と小文字の違い・連続する空白・ハイフンは、表記のゆれです。
  describe '表記のゆれ' do
    def applied(main_terms)
      engine.apply(engine.start(input).add(main_terms: main_terms))
    end

    [
      'Purple to teal gradient background',
      'PURPLE TO TEAL GRADIENT',
      'purple-to-teal gradient',
      'purple to  teal gradient',
      'Floating 3D shapes',
      'floating_3d_shapes'
    ].each do |term|
      it "「#{term}」を取り除きます" do
        expect(applied([term]).main_terms).to be_empty
      end
    end

    it '当たった語は辞書の書き方で残します' do
      draft = applied(['PURPLE TO TEAL GRADIENT'])

      expect(draft.notes.first[:matched]).to eq('purple to teal gradient')
    end
  end

  # 語の形の違いを吸収します（issue #136）。
  #
  # **単数と複数、英国式と米国式のつづり、語の前後の記号、全角の英字は、
  # いずれも「同じ語の別の書き方」です。** 語彙の問題ではありませんので、
  # 照合の側で吸収します。語順の違いと言い換えは、規則辞書の側で扱います。
  describe '語の形の違い' do
    def applied(main_terms)
      engine.apply(engine.start(input).add(main_terms: main_terms))
    end

    # 語の形だけが違う辞書で確かめます。
    let(:forms_dictionary) do
      RuleDictionary.create!(
        version: 'vspec.forms',
        anti_ai_rules: {
          'forbidden_terms' => ['glowing particles', 'oversaturated colors',
                                'purple to teal gradient'],
          'negative_prompt_terms' => ['deformed hands']
        }
      )
    end

    let(:forms_engine) { described_class.new(dictionary: forms_dictionary) }

    def forms_applied(main_terms)
      forms_engine.apply(forms_engine.start(input).add(main_terms: main_terms))
    end

    [
      ['複数形が違います', 'glowing particle effects'],
      ['単数形が違います', 'a glowing particle in the air'],
      ['英国式のつづりです', 'oversaturated colours'],
      ['全角の英字です', 'ＰＵＲＰＬＥ ＴＯ ＴＥＡＬ ＧＲＡＤＩＥＮＴ']
    ].each do |reason, term|
      it "#{reason}：「#{term}」を取り除きます" do
        expect(forms_applied([term]).main_terms).to be_empty
      end
    end

    # **記号を語の一部として扱いません。**
    # `art,` を登録すると `smart, clean layout` が丸ごと落ちていました。
    it '記号を含む語を登録しても、別の語を巻き込みません' do
      dictionary = RuleDictionary.create!(
        version: 'vspec.marks',
        anti_ai_rules: { 'forbidden_terms' => ['art,'], 'negative_prompt_terms' => ['deformed hands'] }
      )
      marks_engine = described_class.new(dictionary: dictionary)
      draft = marks_engine.start(input).add(main_terms: ['smart, clean layout'])

      expect(marks_engine.apply(draft).main_terms).to eq(['smart, clean layout'])
    end

    # **語の内側に記号がある語も、語の切れ目で見ます**（PR #144 のレビューより）。
    it '語の内側に記号がある語でも、別の語を巻き込みません' do
      dictionary = RuleDictionary.create!(
        version: 'vspec.inner-marks',
        anti_ai_rules: { 'forbidden_terms' => ["art's"],
                         'negative_prompt_terms' => ['deformed hands'] }
      )
      marks_engine = described_class.new(dictionary: dictionary)
      draft = marks_engine.start(input).add(main_terms: ["smart's clean layout"])

      expect(marks_engine.apply(draft).main_terms).to eq(["smart's clean layout"])
    end

    it '語の内側に記号がある語そのものは取り除きます' do
      dictionary = RuleDictionary.create!(
        version: 'vspec.inner-marks2',
        anti_ai_rules: { 'forbidden_terms' => ["art's"],
                         'negative_prompt_terms' => ['deformed hands'] }
      )
      marks_engine = described_class.new(dictionary: dictionary)
      draft = marks_engine.start(input).add(main_terms: ["an art's studio"])

      expect(marks_engine.apply(draft).main_terms).to be_empty
    end

    it '記号を含む語そのものは取り除きます' do
      dictionary = RuleDictionary.create!(
        version: 'vspec.marks2',
        anti_ai_rules: { 'forbidden_terms' => ['art,'], 'negative_prompt_terms' => ['deformed hands'] }
      )
      marks_engine = described_class.new(dictionary: dictionary)
      draft = marks_engine.start(input).add(main_terms: ['abstract art, floating'])

      expect(marks_engine.apply(draft).main_terms).to be_empty
    end
  end

  # **関係のない素材を巻き込みません。**
  # 撮影の指示が消えると、requirements.md 4.2 が求める撮影指示を満たせません。
  describe '通してよい素材' do
    def applied(main_terms)
      engine.apply(engine.start(input).add(main_terms: main_terms))
    end

    [
      'a calm office',
      'soft window light',
      '85mm lens, shallow depth of field',
      'a single subtle rim light',
      'bounced fill from a white wall',
      'path traced rendering, neutral tone mapping',
      'stealth startup founders',
      'artisan coffee roastery',
      'a factory line with metal parts',
      '35mm lens',
      'soft lens flare through a window',
      'a glass storefront at dusk'
    ].each do |term|
      it "「#{term}」を残します" do
        expect(applied([term]).main_terms).to eq([term])
      end
    end
  end

  describe '#avoided_compositions' do
    it '既定で避ける構図を返します' do
      expect(engine.avoided_compositions).to eq(['large frontal face close-up'])
    end

    it '定義が無ければ空を返します' do
      without_compositions = RuleDictionary.create!(
        version: 'vspec.no-compositions',
        anti_ai_rules: { 'forbidden_terms' => [], 'negative_prompt_terms' => [] }
      )

      expect(described_class.new(dictionary: without_compositions).avoided_compositions).to be_empty
    end
  end

  # **規則辞書は人が編集するデータです。中身を信用しません。**
  # 空の語が 1 つ混ざるだけで、すべての素材に当たってメインプロンプトが消えます。
  describe '規則辞書の中身' do
    def engine_with(forbidden)
      dictionary = RuleDictionary.create!(
        version: "vspec.terms-#{forbidden.hash.abs}",
        anti_ai_rules: { 'forbidden_terms' => forbidden, 'negative_prompt_terms' => ['x'] }
      )

      described_class.new(dictionary: dictionary)
    end

    it '空の語が混ざっていれば、組み立ての時点で失敗します' do
      expect { engine_with(['purple to teal gradient', '']) }
        .to raise_error(described_class::InvalidDictionaryError)
    end

    it '空白だけの語が混ざっていれば失敗します' do
      expect { engine_with(['purple to teal gradient', '   ']) }
        .to raise_error(described_class::InvalidDictionaryError)
    end

    it '文字列でない語が混ざっていれば失敗します' do
      expect { engine_with(['purple to teal gradient', 123]) }
        .to raise_error(described_class::InvalidDictionaryError)
    end

    it '全角空白だけの語が混ざっていれば失敗します' do
      expect { engine_with(['purple to teal gradient', '　']) }
        .to raise_error(described_class::InvalidDictionaryError)
    end

    it '空の語が混ざっていれば失敗します（nil）' do
      expect { engine_with(['purple to teal gradient', nil]) }
        .to raise_error(described_class::InvalidDictionaryError)
    end

    it '注入する語に空の語が混ざっていれば失敗します' do
      dictionary = RuleDictionary.create!(
        version: 'vspec.empty-negative',
        anti_ai_rules: { 'forbidden_terms' => ['a'], 'negative_prompt_terms' => ['x', ''] }
      )

      expect { described_class.new(dictionary: dictionary) }
        .to raise_error(described_class::InvalidDictionaryError)
    end
  end

  # **英字の語は、語の切れ目で見ます。**
  # `teal` を登録したときに `stealth` を巻き込むと、関係のない指示が消えます。
  describe '短い語を登録した場合' do
    let(:short_terms) do
      RuleDictionary.create!(
        version: 'vspec.short',
        anti_ai_rules: {
          'forbidden_terms' => %w[teal purple glow 3d art neon flare saturated],
          'negative_prompt_terms' => ['x']
        }
      )
    end

    let(:short_engine) { described_class.new(dictionary: short_terms) }

    def kept_by_short(term)
      short_engine.apply(short_engine.start(input).add(main_terms: [term])).main_terms
    end

    [
      'stealth startup founders at a whiteboard',
      'a heartfelt customer testimonial scene',
      'artisan coffee roastery counter',
      'a factory line with metal parts',
      'glowing laptop screen in a dim room',
      'afterglow of sunset over the city'
    ].each do |term|
      it "「#{term}」を巻き込みません" do
        expect(kept_by_short(term)).to eq([term])
      end
    end

    [
      ['teal accent on a brand sign', 'teal'],
      ['3d printed prototype on a workbench', '3d'],
      ['neon lights along the street', 'neon']
    ].each do |term, matched|
      it "「#{term}」は取り除きます" do
        expect(kept_by_short(term)).to be_empty
      end

      it "「#{term}」で当たった語は #{matched} です" do
        draft = short_engine.apply(short_engine.start(input).add(main_terms: [term]))

        expect(draft.notes.first[:matched]).to eq(matched)
      end
    end
  end

  # **1つの下書きへ当てる規則辞書は1つだけです。**
  # 生成リクエストが持てる版は1つですので、別の版を重ねると、
  # 前の版で適用した事実が記録から消えます。
  describe '別の版を重ねた場合' do
    let(:other_dictionary) do
      RuleDictionary.create!(
        version: 'vspec.other',
        anti_ai_rules: { 'forbidden_terms' => ['a'], 'negative_prompt_terms' => ['x'] }
      )
    end

    it '重ねて当てようとすると失敗します' do
      applied = engine.apply(engine.start(input))
      other = described_class.new(dictionary: other_dictionary)

      expect { other.apply(applied) }.to raise_error(described_class::VersionMismatchError)
    end

    it '同じ版なら重ねて当てられます' do
      applied = engine.apply(engine.start(input))

      expect { engine.apply(applied) }.not_to raise_error
    end

    it '版がまだ無い下書きには当てられます' do
      bare = Generation::Draft.new(input: input)

      expect(engine.apply(bare).dictionary_version).to eq('vspec.rules')
    end
  end

  describe '素材の型' do
    def applied(main_terms)
      engine.apply(engine.start(input).add(main_terms: main_terms))
    end

    it '文字列でない素材は失敗させます' do
      expect { applied([123]) }.to raise_error(described_class::InvalidDraftError)
    end

    it '空の素材は失敗させます' do
      expect { applied([nil]) }.to raise_error(described_class::InvalidDraftError)
    end
  end

  describe '#avoided_compositions の複製' do
    it '返した一覧へ足しても、規則の中身は変わりません' do
      engine.avoided_compositions << 'すり替えました'

      expect(engine.avoided_compositions).to eq(['large frontal face close-up'])
    end
  end

  describe '規則辞書の不備' do
    it '辞書が無ければ組み立てられません' do
      expect { described_class.new(dictionary: nil) }
        .to raise_error(described_class::MissingDictionaryError)
    end

    it '排除する語の定義が無ければ失敗します' do
      broken = RuleDictionary.create!(version: 'vspec.broken-rules',
                                      anti_ai_rules: { 'negative_prompt_terms' => [] })

      expect { described_class.new(dictionary: broken) }
        .to raise_error(described_class::InvalidDictionaryError)
    end

    it '注入する語の定義が無ければ失敗します' do
      broken = RuleDictionary.create!(version: 'vspec.broken-rules2',
                                      anti_ai_rules: { 'forbidden_terms' => [] })

      expect { described_class.new(dictionary: broken) }
        .to raise_error(described_class::InvalidDictionaryError)
    end
  end

  # 仕様（requirements.md 4.2）が挙げるクリシェを、規則として書けることを確かめます。
  #
  # **`db/seeds.rb` を読み込みません。** seeds は同じ版があれば何もしないため、
  # 読み込む形にすると、テスト用データベースに残っている行の状態でテストの結果が
  # 変わります。初期データそのものの中身は `spec/models/rule_dictionary_spec.rb`
  # が確かめます。ここで確かめるのは、規則を当てる仕組みの側です。
  describe '仕様が挙げるクリシェ' do
    let(:spec_dictionary) do
      RuleDictionary.create!(
        version: 'vspec.cliche',
        anti_ai_rules: {
          'forbidden_terms' => [
            'purple to teal gradient',
            'floating 3d shapes',
            'hyper saturated',
            'lens flare everywhere'
          ],
          'negative_prompt_terms' => [
            'oversaturation', 'excessive bokeh', 'deformed hands', 'extra fingers'
          ]
        }
      )
    end

    let(:spec_engine) { described_class.new(dictionary: spec_dictionary) }

    it 'クリシェ配色を排除します' do
      draft = spec_engine.apply(
        spec_engine.start(input).add(main_terms: ['purple to teal gradient', 'a calm office'])
      )

      expect(draft.main_terms).to eq(['a calm office'])
    end

    it '意味の無い浮遊物を排除します' do
      draft = spec_engine.apply(spec_engine.start(input).add(main_terms: ['floating 3d shapes']))

      expect(draft.main_terms).to be_empty
    end

    it '破綻した手指を避ける語を注入します' do
      draft = spec_engine.apply(spec_engine.start(input))

      expect(draft.negative_terms).to include('deformed hands', 'extra fingers')
    end

    it '過剰な彩度とボケを避ける語を注入します' do
      draft = spec_engine.apply(spec_engine.start(input))

      expect(draft.negative_terms).to include('oversaturation', 'excessive bokeh')
    end
  end
end
