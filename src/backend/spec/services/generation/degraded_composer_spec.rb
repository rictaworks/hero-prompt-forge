# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::DegradedComposer do
  let(:terms) { ['a calm office', 'clear copy space across the left third of the frame'] }
  let(:draft) { Generation::Draft.new(input: { industry: 'saas' }, main_terms: terms) }
  let(:refiner) { instance_double(Generation::LlmRefiner) }
  let(:composer) { described_class.new(refiner: refiner) }

  def with_key(present)
    allow(Generation::LlmRefiner).to receive(:available?).and_return(present)
  end

  def degraded_note(result)
    result.notes.find { |note| note[:kind] == described_class::NOTE_KIND }
  end

  describe 'LLM が使える場合' do
    before { with_key(true) }

    it '磨いた下書きを返します' do
      refined = draft.add(main_terms: ['a quiet office'])
      allow(refiner).to receive(:refine).and_return(refined)

      expect(composer.compose(draft)).to eq(refined)
    end

    it '縮退の印を残しません' do
      allow(refiner).to receive(:refine).and_return(draft)

      expect(described_class.degraded?(composer.compose(draft))).to be(false)
    end
  end

  # **リトライ上限に達したら縮退します。**
  describe '呼び出しが失敗する場合' do
    before do
      with_key(true)
      allow(refiner).to receive(:refine).and_raise(Generation::LlmRefiner::RequestFailedError)
    end

    it '決めた回数だけ試します' do
      composer.compose(draft)

      expect(refiner).to have_received(:refine).twice
    end

    it '縮退した下書きを返します' do
      expect(described_class.degraded?(composer.compose(draft))).to be(true)
    end

    it '理由を控えへ残します' do
      expect(degraded_note(composer.compose(draft))[:reason]).to eq(:llm_failed)
    end

    # **規則の適用とコピースペースの規定は、通常どおり行われます。**
    it '素材を落としません' do
      expect(composer.compose(draft).main_terms).to eq(terms)
    end

    it '余白の指定を保ちます' do
      expect(Generation::CopySpace.reserved?(composer.compose(draft))).to be(true)
    end
  end

  describe '磨いた結果が受け取れない場合' do
    before do
      with_key(true)
      allow(refiner).to receive(:refine).and_raise(Generation::LlmRefiner::InvalidRefinementError)
    end

    it '縮退します' do
      expect(described_class.degraded?(composer.compose(draft))).to be(true)
    end

    it '理由を分けて残します' do
      expect(degraded_note(composer.compose(draft))[:reason]).to eq(:llm_unusable_result)
    end
  end

  # **API キーが無ければ、呼び出さずに縮退します。**
  describe 'LLM が使えない場合' do
    before { with_key(false) }

    it '呼び出しません' do
      allow(refiner).to receive(:refine)
      composer.compose(draft)

      expect(refiner).not_to have_received(:refine)
    end

    it '縮退します' do
      expect(described_class.degraded?(composer.compose(draft))).to be(true)
    end

    it '理由を残します' do
      expect(degraded_note(composer.compose(draft))[:reason]).to eq(:llm_unavailable)
    end
  end
end
