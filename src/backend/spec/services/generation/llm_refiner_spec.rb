# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Generation::LlmRefiner do
  let(:terms) do
    ['a calm office', 'a 35mm lens', 'clear copy space across the left third of the frame']
  end

  let(:draft) { Generation::Draft.new(input: { industry: 'saas' }, main_terms: terms) }

  # **外部への通信は差し替えます。**
  let(:client) { instance_double(Generation::GeminiClient) }

  let(:refiner) { described_class.new(client: client) }

  def answering(lines)
    allow(client).to receive(:refine).and_return(lines)
  end

  describe '磨いた結果' do
    let(:refined) do
      ['a calm and quiet office interior',
       'a 35mm lens at eye level',
       'clear copy space across the left third of the frame']
    end

    before { answering(refined) }

    it '磨いた素材へ差し替えます' do
      expect(refiner.refine(draft).main_terms).to eq(refined)
    end

    it '磨いた事実を控えへ残します' do
      note = refiner.refine(draft).notes.find { |item| item[:kind] == described_class::NOTE_KIND }

      expect(note[:model]).to eq('gemini-2.5-flash-lite')
    end

    it 'もとの下書きを変えません' do
      refiner.refine(draft)

      expect(draft.main_terms).to eq(terms)
    end

    it '素材が無ければ、そのまま返します' do
      empty = Generation::Draft.new(input: {})

      expect(refiner.refine(empty)).to eq(empty)
    end
  end

  # **磨いたつもりで壊れている状態を残しません。**
  describe '受け取れない結果' do
    it '素材の数が変われば失敗します' do
      answering(['a calm office'])

      expect { refiner.refine(draft) }.to raise_error(described_class::InvalidRefinementError)
    end

    it '日本語が混ざれば失敗します' do
      answering(['落ち着いた事務所', 'a 35mm lens',
                 'clear copy space across the left third of the frame'])

      expect { refiner.refine(draft) }.to raise_error(described_class::InvalidRefinementError)
    end

    # **コピースペースの指定は最上位です。**
    it '余白の指定が消えれば失敗します' do
      answering(['a calm office', 'a 35mm lens', 'a wide open interior'])

      expect { refiner.refine(draft) }.to raise_error(described_class::InvalidRefinementError)
    end
  end

  describe '呼び出しの失敗' do
    it 'そのまま投げます' do
      allow(client).to receive(:refine).and_raise(Generation::GeminiClient::RequestFailedError)

      expect { refiner.refine(draft) }.to raise_error(described_class::RequestFailedError)
    end
  end

  # **送るのは、磨く対象の英文だけです。**
  describe '送る内容' do
    it '指示文と素材だけを送ります' do
      answering(terms)
      refiner.refine(draft)

      expect(client).to have_received(:refine).with(instruction: a_string_including('art director'),
                                                    lines: terms)
    end
  end

  # **API キーが用意されているかどうかを見ます。**
  describe '使えるかどうか' do
    it 'キーがなければ使えません' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with(Generation::GeminiClient::API_KEY_VARIABLE).and_return(nil)

      expect(described_class).not_to be_available
    end

    it 'キーがあれば使えます' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with(Generation::GeminiClient::API_KEY_VARIABLE).and_return('key')

      expect(described_class).to be_available
    end
  end
end
