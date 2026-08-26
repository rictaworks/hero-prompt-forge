# frozen_string_literal: true

module Generation
  # 入力で選べる値と、その上限です（requirements.md 4.1）。
  #
  # 検証と正規化の両方から参照します。**一覧を書き写しません。**
  # 既存の定義があるものは、そのまま参照します。書き写すと、片方だけを
  # 増やしたときに、保存はできるのに生成では弾かれる（またはその逆の）
  # 食い違いが静かに生まれます。
  module InputChoices
    # 選択肢です。
    INDUSTRIES = Project::INDUSTRIES
    STYLE_FAMILIES = Project::STYLE_FAMILIES
    TARGET_MODELS = PromptRequest::TARGET_MODELS
    BRAND_TONES = %w[trust advanced warmth premium friendly minimal].freeze
    COPY_SPACE_POSITIONS = %w[left right bottom_center].freeze
    ASPECT_RATIOS = ['16:9', '21:9', '3:2'].freeze

    # 既定値です。
    DEFAULT_COPY_SPACE_POSITION = 'left'
    DEFAULT_ASPECT_RATIO = '16:9'

    # 上限です。
    MAX_BRAND_COLORS = 2
    MAX_SERVICE_SUMMARY_LENGTH = 1000

    BRAND_COLOR_FORMAT = /\A#[0-9a-fA-F]{6}\z/

    # 受け取る項目です。ここに無い項目は取り込みません。
    KNOWN_FIELDS = %i[
      industry style_family target_model brand_tone
      service_summary brand_colors copy_space_position aspect_ratio
    ].freeze
  end
end
