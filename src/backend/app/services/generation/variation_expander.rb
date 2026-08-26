# frozen_string_literal: true

module Generation
  # バリエーション3案の展開です（requirements.md 4.1 の 8、4.2）。
  #
  # **構図の異なる 3 案を出します。** 同じ絵の色違いではありません。
  # **何を主役にするか**を変えます。
  #
  #   subject_led         : 被写体主導。人や物を主役にします
  #   environment_led     : 環境主導。場所と空気を主役にします
  #   abstract_background : 抽象背景。具体物を置かず、面と光で見せます
  #
  # **主役の置き方だけを変えるのではありません。** スタイル仕様化規則が一覧で
  # 選べる値を持つ場合（レンズ焦点距離・人物を避ける構図）は、**案ごとに別の値へ
  # 選び直します。** 同じレンズ・同じ構図のまま主役だけを入れ替えても、
  # 3 案が似通います。
  #
  # **抽象背景の案からは、人物を避ける構図を外します。** 具体物を置かない案に
  # 「後ろ姿の被写体」を指示すると、抽象背景という指定と食い違います。
  #
  # **元の下書きを変えません。** 3 案はそれぞれ別の下書きとして返します。
  class VariationExpander
    # 規則辞書が渡されていない場合に投げます。
    class MissingDictionaryError < StandardError; end

    # 展開の規則が読めない、または内容が足りない場合に投げます。
    InvalidDefinitionError = VariationRules::InvalidDefinitionError

    # すでに展開済みの下書きを、もう一度展開しようとした場合に投げます。
    class AlreadyExpandedError < StandardError; end

    # スタイル仕様化を通っていない下書きを渡された場合に投げます。
    class MissingSpecificationsError < StandardError; end

    # ノートに残す印です。文言ではなく記号で持ちます。
    NOTE_KIND = :variation

    # 抽象背景の案から人物の構図を外したことを残す印です。
    PERSON_SAFETY_DROPPED_NOTE_KIND = :person_safety_dropped

    def initialize(dictionary:)
      raise MissingDictionaryError, '規則辞書がありません。' if dictionary.nil? # 開発者向け

      @rules = StyleRules.new(dictionary)
      @definition = VariationRules.load
    end

    # 3 案へ展開した下書きを返します。
    # @return [Array<Draft>]
    def expand(draft)
      ensure_not_expanded!(draft)
      applied = specifications_note_of(draft)

      Trace.step('generation.variations_expanded',
                 style_family: applied[:style_family], variations: order.size) do
        order.each_with_index.map { |name, index| variation(draft, applied, name, index) }
      end
    end

    # その下書きが展開済みかどうかを返します。
    def self.expanded?(draft)
      draft.notes.any? { |note| note[:kind] == NOTE_KIND }
    end

    private

    attr_reader :rules, :definition

    def order
      definition.fetch(VariationRules::ORDER_KEY)
    end

    def composition_for(name)
      definition.fetch(VariationRules::COMPOSITIONS_KEY).fetch(name)
    end

    # 1 案を組み立てます。
    def variation(draft, applied, name, index)
      composition = composition_for(name)
      terms = swapped_terms(draft, applied, name, index)

      draft.replace(main_terms: terms).add(
        main_terms: [composition.fetch(VariationRules::FOCUS_KEY)],
        notes: [variation_note(name, index)] + dropped_notes(draft, composition)
      )
    end

    def variation_note(name, index)
      { kind: NOTE_KIND, composition: name, number: index + 1 }
    end

    # **抽象背景の案から外した事実を残します。**
    def dropped_notes(draft, composition)
      return [] if composition.fetch(VariationRules::KEEPS_PEOPLE_KEY)

      dropped = person_safety_terms(draft)
      return [] if dropped.empty?

      [{ kind: PERSON_SAFETY_DROPPED_NOTE_KIND, compositions: dropped }]
    end

    # 案ごとに、一覧で選べる値を選び直します。
    def swapped_terms(draft, applied, name, index)
      replacements = specification_replacements(applied, index)
                     .merge(person_safety_replacements(draft, name, index))

      draft.main_terms.filter_map { |term| replacements.key?(term) ? replacements[term] : term }
    end

    # スタイル仕様化が当てた指示を、案ごとの値へ差し替えます。
    def specification_replacements(applied, index)
      chosen = rules.specifications_for(applied[:style_family], variation: index)

      applied[:specifications].zip(chosen).to_h
    end

    # 人物を避ける構図を、案ごとの構図へ差し替えます。
    #
    # **抽象背景の案では外します。** `nil` を返すと、その素材は落ちます。
    def person_safety_replacements(draft, name, index)
      applied = person_safety_terms(draft)
      return {} if applied.empty?

      keeps_people = composition_for(name).fetch(VariationRules::KEEPS_PEOPLE_KEY)
      return applied.index_with { nil } unless keeps_people

      choices = rules.person_safety_for(style_family_of(draft))
      applied.each_with_index.to_h { |term, offset| [term, choices[(index + offset) % choices.size]] }
    end

    def person_safety_terms(draft)
      note = draft.notes.find { |item| item[:kind] == StyleSpec::PERSON_SAFETY_NOTE_KIND }
      note ? Array(note[:compositions]) : []
    end

    def style_family_of(draft)
      specifications_note_of(draft)[:style_family]
    end

    # **スタイル仕様化を通っていない下書きは展開しません。**
    # どの指示を選び直せばよいのか決められません。
    def specifications_note_of(draft)
      note = draft.notes.find { |item| item[:kind] == StyleSpec::SPECIFICATIONS_NOTE_KIND }
      return note if note

      raise MissingSpecificationsError,
            'スタイル仕様化を通っていない下書きは展開できません。' # 開発者向け
    end

    # **2 回展開しません。** 案の中でさらに 3 案へ分かれ、9 案になります。
    def ensure_not_expanded!(draft)
      return unless self.class.expanded?(draft)

      raise AlreadyExpandedError, 'すでに展開済みです。' # 開発者向け
    end
  end
end
