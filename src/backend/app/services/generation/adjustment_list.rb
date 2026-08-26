# frozen_string_literal: true

module Generation
  # アートディレクションノートの「この案で調整したこと」です
  # （requirements.md 4.1 の 9）。
  #
  # **控え（ノート）から組み立てます。推し量りません。**
  # 各段は、何をどう扱ったかを控えへ残しています。**控えに無いことは書きません。**
  #
  # **文言を実装の中へ書きません。** `config/locales/ja.yml` にあります。
  #
  # **人物の見込みをサイトの設定で上書きした場合の一文は、まだ足していません。**
  # 上書きの仕組み（issue #147）が別の PR で進んでいるためです。**文言だけを
  # 先に用意してあります**（`adjustments.person_safety_from_project`）。
  class AdjustmentList
    SCOPE = "#{ArtDirectionNote::SCOPE}.adjustments".freeze
    ROLES_SCOPE = "#{ArtDirectionNote::SCOPE}.labels.roles".freeze

    def initialize(draft)
      @draft = draft
    end

    # @return [Array<String>]
    def build
      draft.notes.filter_map { |note| line_for(note) }
    end

    private

    attr_reader :draft

    def line_for(note)
      case note[:kind]
      when ConflictResolver::BRAND_COLOR_NOTE_KIND then brand_color(note)
      when StylePalette::NOTE_KIND then text('style_palette_weakened')
      when ConflictResolver::TONE_NOTE_KIND then tone(note)
      when RuleEngine::REMOVED_NOTE_KIND then text('anti_ai_removed', term: note[:term])
      when VariationExpander::DROPPED_NOTE_KIND then dropped(note)
      end
    end

    # **弱めたのか、そのまま入れたのかを分けて伝えます。**
    # 「弱める」は「見えなくする」ことではありません。
    def brand_color(note)
      key = case note[:strength]
            when BrandColorIntegration::WEAKENED then 'brand_color_weakened'
            when BrandColorIntegration::SECONDARY_ACCENT then 'brand_color_secondary'
            else 'brand_color_accent'
            end

      text(key, name: note[:name], color: note[:color])
    end

    def tone(note)
      return nil unless note[:restrained]

      text('tone_restrained')
    end

    def dropped(note)
      text('variation_dropped', role: role_label(note[:role]))
    end

    # **既定へ寄せません。** 役割の呼び名が無いまま通すと、
    # `lens_mm` のような開発者向けの名前が利用者へ出ます（PR #159 のレビューより）。
    def role_label(role)
      I18n.t("#{ROLES_SCOPE}.#{role}")
    end

    def text(key, **)
      I18n.t("#{SCOPE}.#{key}", **)
    end
  end
end
