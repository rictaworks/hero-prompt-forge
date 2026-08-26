# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::CopySpace do
  let(:copy_space) { described_class.new }

  def draft_for(position: 'left', aspect_ratio: '16:9', **extra)
    Generation::Draft.new(
      input: { industry: 'saas', style_family: 'photoreal',
               copy_space_position: position, aspect_ratio: aspect_ratio }.merge(extra)
    )
  end

  def applied(**options)
    copy_space.apply(draft_for(**options))
  end

  # **コピースペースを持たない案を出しません**（requirements.md 4.2）。
  describe 'コピースペースの確保' do
    Generation::InputChoices::COPY_SPACE_POSITIONS.each do |position|
      it "#{position}：余白の指定を足します" do
        expect(applied(position: position).main_terms).to include(a_string_including('copy space'))
      end

      it "#{position}：確保した事実をノートへ残します" do
        note = applied(position: position).notes.first

        expect(note[:kind]).to eq(described_class::NOTE_KIND)
        expect(note[:position]).to eq(position)
      end

      it "#{position}：確保したことを外から確かめられます" do
        expect(described_class.reserved?(applied(position: position))).to be(true)
      end
    end

    it '確保していない下書きは、確保済みと見なしません' do
      expect(described_class.reserved?(draft_for)).to be(false)
    end
  end

  # **被写体と視線誘導が余白側と競合しない配置**（requirements.md 4.1 の 4）。
  describe '被写体と視線誘導' do
    it '左に余白なら、被写体を右へ寄せます' do
      terms = applied(position: 'left').main_terms

      expect(terms).to include(a_string_including('right third intersection'))
    end

    it '右に余白なら、被写体を左へ寄せます' do
      terms = applied(position: 'right').main_terms

      expect(terms).to include(a_string_including('left third intersection'))
    end

    it '下中央に余白なら、被写体を上へ寄せます' do
      terms = applied(position: 'bottom_center').main_terms

      expect(terms).to include(a_string_including('upper third line'))
    end

    it '視線を余白側へ導きます' do
      terms = applied(position: 'left').main_terms

      expect(terms).to include(a_string_including('oriented toward the left'))
    end

    it '視線誘導が余白へ入り込まないことを明示します' do
      terms = applied(position: 'left').main_terms

      expect(terms).to include(a_string_including('without extending into it'))
    end

    it '余白の帯を静かに保ちます' do
      terms = applied(position: 'left').main_terms

      expect(terms).to include(a_string_including('free of competing detail'))
    end

    it '三分割構図を指定します' do
      terms = applied(position: 'left').main_terms

      expect(terms).to include(a_string_including('rule of thirds'))
    end
  end

  describe 'アスペクト比' do
    Generation::InputChoices::ASPECT_RATIOS.each do |ratio|
      it "#{ratio}：構図の言い方を足します" do
        expect(applied(aspect_ratio: ratio).main_terms)
          .to include(a_string_including(ratio))
      end
    end

    it 'ノートへも残します' do
      expect(applied(aspect_ratio: '21:9').notes.first[:aspect_ratio]).to eq('21:9')
    end
  end

  describe '素材の作り方' do
    it '1件1指示で足します。1件へ詰め込みません' do
      terms = applied.main_terms

      expect(terms).to all(satisfy { |term| term.exclude?(' and ') })
    end

    it '打ち消しの言い回しを作りません' do
      terms = applied.main_terms

      expect(terms).to all(satisfy { |term| !term.match?(/\A(no|not|without) /) })
    end

    it '日本語の素材を作りません' do
      terms = applied.main_terms

      expect(terms).to all(satisfy { |term| !term.match?(/[ぁ-んァ-ヶ一-龥]/) })
    end

    it '役割の数だけ足します' do
      # 余白・被写体・視線誘導・静けさ・アスペクト比の 5 件です。
      expect(applied.main_terms.size).to eq(5)
    end
  end

  describe '下書きの引き継ぎ' do
    it 'すでにある素材を残します' do
      draft = draft_for.add(main_terms: ['35mm lens'])

      expect(copy_space.apply(draft).main_terms).to include('35mm lens')
    end

    it 'すでにあるノートを残します' do
      draft = draft_for.add(notes: [{ kind: :person_safety_applied }])

      expect(copy_space.apply(draft).notes.size).to eq(2)
    end

    it 'もとの下書きを変えません' do
      draft = draft_for
      copy_space.apply(draft)

      expect(draft.main_terms).to be_empty
    end
  end

  describe '想定外の入力' do
    it 'コピースペース位置が無ければ失敗します' do
      bare = Generation::Draft.new(input: { aspect_ratio: '16:9' })

      expect { copy_space.apply(bare) }.to raise_error(described_class::MissingPositionError)
    end

    it 'アスペクト比が無ければ失敗します' do
      bare = Generation::Draft.new(input: { copy_space_position: 'left' })

      expect { copy_space.apply(bare) }.to raise_error(described_class::MissingAspectRatioError)
    end

    it '定義されていない位置なら失敗します' do
      expect { applied(position: 'top') }.to raise_error(described_class::UnknownPositionError)
    end

    it '定義されていないアスペクト比なら失敗します' do
      expect { applied(aspect_ratio: '1:1') }
        .to raise_error(described_class::UnknownAspectRatioError)
    end
  end

  # **定義の中身を検めます。** 位置ごとの役割が欠けたまま通すと、
  # コピースペースの指定を欠いた案が出ます。
  describe '定義の検め' do
    after { Generation::CopySpaceRules.reset! }

    it '仕様が定める 3 つの位置をすべて持ちます' do
      expect(Generation::CopySpaceRules.positions.keys)
        .to match_array(Generation::InputChoices::COPY_SPACE_POSITIONS)
    end

    it '仕様が定める 3 つのアスペクト比をすべて持ちます' do
      expect(Generation::CopySpaceRules.aspect_ratios.keys)
        .to match_array(Generation::InputChoices::ASPECT_RATIOS)
    end

    it '位置ごとに 4 つの役割を持ちます' do
      Generation::InputChoices::COPY_SPACE_POSITIONS.each do |position|
        expect(Generation::CopySpaceRules.instructions_for(position).size).to eq(4)
      end
    end

    it 'すべての指示が、そのまま読める英文です' do
      Generation::InputChoices::COPY_SPACE_POSITIONS.each do |position|
        expect(Generation::CopySpaceRules.instructions_for(position))
          .to all(match(/[a-z]{3,}/))
      end
    end

    it '定義が読めなければ失敗します' do
      allow(YAML).to receive(:safe_load_file).and_return('壊れています')
      Generation::CopySpaceRules.reset!

      expect { Generation::CopySpaceRules.positions }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '位置が足りなければ失敗します' do
      allow(YAML).to receive(:safe_load_file)
        .and_return({ 'positions' => { 'left' => {} }, 'aspect_ratios' => {} })
      Generation::CopySpaceRules.reset!

      expect { Generation::CopySpaceRules.positions }
        .to raise_error(described_class::InvalidDefinitionError)
    end

    it '役割の値が英文でなければ失敗します' do
      broken = { 'positions' => Generation::InputChoices::COPY_SPACE_POSITIONS.index_with do
        { 'reserved' => 24, 'subject' => 'a', 'gaze' => 'b', 'restraint' => 'c' }
      end, 'aspect_ratios' => Generation::InputChoices::ASPECT_RATIOS.index_with { 'x' } }
      allow(YAML).to receive(:safe_load_file).and_return(broken)
      Generation::CopySpaceRules.reset!

      expect { Generation::CopySpaceRules.positions }
        .to raise_error(described_class::InvalidDefinitionError)
    end
  end
end
