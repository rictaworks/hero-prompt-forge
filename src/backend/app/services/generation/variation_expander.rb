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
  # **抽象背景の案からは、被写体があることを前提にした指示を外します。**
  # 具体物を置かない案に「後ろ姿の被写体」「被写体の面の被写界深度」
  # 「被写体を三分割の交点へ置く」を指示すると、抽象背景という指定と食い違います。
  # **外す素材は、規則の側で役割の名前として持ちます。**
  #
  # **元の下書きを変えません。** 3 案はそれぞれ別の下書きとして返します。
  #
  # 1 案の組み立ては VariationBuilder が持ちます。
  class VariationExpander
    # 規則辞書が渡されていない場合に投げます。
    class MissingDictionaryError < StandardError; end

    # 展開の規則が読めない、または内容が足りない場合に投げます。
    InvalidDefinitionError = VariationRules::InvalidDefinitionError

    # すでに展開済みの下書きを、もう一度展開しようとした場合に投げます。
    class AlreadyExpandedError < StandardError; end

    # スタイル仕様化を通っていない下書きを渡された場合に投げます。
    class MissingSpecificationsError < StandardError; end

    # 別の版の規則辞書で作られた下書きを渡された場合に投げます。
    class VersionMismatchError < StandardError; end

    # ノートに残す印です。文言ではなく記号で持ちます。
    NOTE_KIND = :variation

    # 案ごとに素材を外したことを残す印です。
    DROPPED_NOTE_KIND = :variation_dropped

    def initialize(dictionary:)
      raise MissingDictionaryError, '規則辞書がありません。' if dictionary.nil? # 開発者向け

      @rules = StyleRules.new(dictionary)
      @definition = VariationRules.load
    end

    # 3 案へ展開した下書きを返します。
    # @return [Array<Draft>]
    def expand(draft)
      ensure_not_expanded!(draft)
      ensure_specifications!(draft)
      ensure_same_version!(draft)

      order.each_with_index.map { |name, index| builder_for(name, index).build(draft) }
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

    def builder_for(name, index)
      composition = definition.fetch(VariationRules::COMPOSITIONS_KEY).fetch(name)

      VariationBuilder.new(rules: rules, composition: composition, name: name, index: index)
    end

    # **スタイル仕様化を通っていない下書きは展開しません。**
    # どの指示を選び直せばよいのか決められません。
    def ensure_specifications!(draft)
      return if draft.notes.any? { |item| item[:kind] == StyleSpec::SPECIFICATIONS_NOTE_KIND }

      raise MissingSpecificationsError,
            'スタイル仕様化を通っていない下書きは展開できません。' # 開発者向け
    end

    # **別の版の規則辞書で作られた下書きは展開しません。**
    # 控えの指示と、いま引ける指示が食い違い、素材が黙って落ちます。
    def ensure_same_version!(draft)
      applied_version = draft.dictionary_version
      return if applied_version.nil? || applied_version == rules.version

      raise VersionMismatchError,
            "別の版の下書きは展開できません: #{applied_version} -> #{rules.version}" # 開発者向け
    end

    # **2 回展開しません。** 案の中でさらに 3 案へ分かれ、9 案になります。
    def ensure_not_expanded!(draft)
      return unless self.class.expanded?(draft)

      raise AlreadyExpandedError, 'すでに展開済みです。' # 開発者向け
    end
  end
end
