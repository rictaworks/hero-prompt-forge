# frozen_string_literal: true

require 'rails_helper'

# 初期の規則辞書の**中身**を確かめます（issue #137）。
#
# 規則辞書の初期データは、この製品の中核となる価値（AI っぽさを設計段階で
# 外すこと）を担うデータです。**語の有無だけを見ると、仕様が挙げるクリシェを
# 消しても気づけません。** requirements.md 4.2 が挙げる 4 種別と、4.1 の 3 が
# 求める撮影指示、4.1 の 1 が挙げる 10 業種を、それぞれ名指しで確かめます。
#
# **テスト用データベースの状態に左右されません。** `db/seeds.rb` を読み込まず、
# 定義ファイルを直接読みます。読み込む形にすると、初期データが投入済みか
# どうかでテストの結果が変わります。
RSpec.describe InitialRuleDictionary do
  # 排除する語と注入する語を、まとめて 1 つの文字列にして照合します。
  # どちらへ書かれていても、その表現に対処できている事実は変わりません。
  def anti_ai_text
    (forbidden_terms + negative_prompt_terms).join(' ').downcase
  end

  # メインプロンプトから取り除く語です。
  def forbidden_terms
    described_class.anti_ai_rules.fetch('forbidden_terms')
  end

  # ネガティブプロンプトへ必ず入れる語です。
  def negative_prompt_terms
    described_class.anti_ai_rules.fetch('negative_prompt_terms')
  end

  # **二方向のどちらかが空になっていないことを、別々に確かめます。**
  # まとめて照合するだけでは、片方を空にしても気づけません。
  # 排除だけでは表記のゆれを取りこぼし、注入だけでは利用者の指定した語が
  # メインプロンプトに残ります。両方がそろって初めて効きます。
  describe '二方向の守り' do
    it 'メインプロンプトから取り除く語を持ちます' do
      expect(forbidden_terms).to be_present
    end

    it 'ネガティブプロンプトへ入れる語を持ちます' do
      expect(negative_prompt_terms).to be_present
    end

    it '取り除く語が、そのままプロンプトへ入れられる文字列です' do
      expect(forbidden_terms).to all(be_a(String).and(be_present))
    end

    it '入れる語が、そのままプロンプトへ入れられる文字列です' do
      expect(negative_prompt_terms).to all(be_a(String).and(be_present))
    end

    it '取り除く語に、クリシェ配色が入っています' do
      expect(forbidden_terms.join(' ').downcase).to match(/purple.*teal|teal.*purple/)
    end

    it '入れる語に、破綻した手指が入っています' do
      expect(negative_prompt_terms.join(' ').downcase).to match(/hands|fingers/)
    end
  end

  describe 'requirements.md 4.2 が挙げる 4 種別' do
    it 'クリシェ配色（紫からティールの階調）に対処します' do
      expect(anti_ai_text).to match(/purple.*teal|teal.*purple/)
    end

    it '意味を持たない浮遊オブジェクトに対処します' do
      expect(anti_ai_text).to include('floating')
    end

    it '過剰な彩度に対処します' do
      expect(anti_ai_text).to include('saturat')
    end

    it '過剰なボケに対処します' do
      expect(anti_ai_text).to match(/bokeh|lens flare/)
    end

    it '破綻した手指に対処します' do
      expect(anti_ai_text).to match(/hands|fingers/)
    end
  end

  describe 'requirements.md 4.2 が求める既定の回避' do
    it '顔を正面から大きく描く構図を既定で避けます' do
      compositions = described_class.anti_ai_rules.fetch('avoided_compositions')

      expect(compositions.join(' ').downcase).to include('face')
    end

    it '実写系に、顔と手指の破綻を避ける構図を持ちます' do
      photoreal = described_class.style_spec_rules.fetch('photoreal')

      expect(photoreal.fetch('person_safety')).to be_present
    end
  end

  describe 'requirements.md 4.1 の 3 が求める撮影指示' do
    # 実写系が必ず出す項目です。1 つでも欠けると、撮影指示を欠いた
    # プロンプトが出ます。4.2 はそれを禁じています。
    let(:required_photoreal_items) do
      %w[lens_mm key_light fill_light rim_light depth_of_field]
    end

    it '実写系がレンズ焦点距離・照明設計・被写界深度を必須とします' do
      required = described_class.style_spec_rules.fetch('photoreal').fetch('required')

      expect(required).to include(*required_photoreal_items)
    end

    it '必須の項目がすべて値を持ちます' do
      spec = Generation::StyleRules.new(
        RuleDictionary.new(version: 'vspec.initial',
                           style_spec_rules: described_class.style_spec_rules)
      )

      expect(spec.specifications_for('photoreal').size).to eq(required_photoreal_items.size)
    end
  end

  describe 'requirements.md 4.1 の 1 が挙げる業種' do
    it '仕様の 10 業種をすべて持ちます' do
      expect(described_class.industry_defaults.keys).to match_array(Project::INDUSTRIES)
    end

    it 'すべての業種が標準トーンを持ちます' do
      tones = described_class.industry_defaults.values.pluck('tone')

      expect(tones).to all(be_in(Generation::InputChoices::BRAND_TONES))
    end
  end

  describe '定義の読み込み' do
    it 'テスト用データベースの状態に左右されません' do
      RuleDictionary.delete_all

      expect(described_class.version).to be_present
    end

    it '定義ファイルが無ければ失敗します' do
      expect { described_class.definition(path: 'config/rule_dictionary/absent.yml') }
        .to raise_error(described_class::InvalidDefinitionError)
    end
  end
end
