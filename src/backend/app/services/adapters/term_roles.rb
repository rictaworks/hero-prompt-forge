# frozen_string_literal: true

module Adapters
  # 素材の役割です（issue #156）。
  #
  # **控え（ノート）から受け取ります。** 各段は、当てた素材がどの役割の
  # ものかを控えへ残しています（撮影の手段・描き方・構図・配色・雰囲気）。
  #
  # **素材の文字列を照合して見分けません。** 言い回しが変わったときに黙って
  # 外れます（PR #154 ・ #155 のレビューより）。
  #
  # **控えに役割が無い素材もあります。** 利用者が書いたサービス概要から作った
  # 素材などです。**その場合は、既定の述語で述べます。**
  class TermRoles
    # 控えに置かれた役割の対応の鍵です。**`役割 => 素材` の向きで持ちます。**
    ROLES_KEY = :roles

    # 素材から役割への対応を返します。
    # @return [Hash{String => String}]
    def self.of(draft)
      draft.notes.each_with_object({}) do |note, found|
        roles = note.is_a?(Hash) ? note[ROLES_KEY] : nil
        next unless roles.is_a?(Hash)

        roles.each { |role, term| found[term] = role.to_s if term.is_a?(String) }
      end
    end
  end
end
