# frozen_string_literal: true

class DeveloperOnly
  def check(value)
    raise ArgumentError, '値が空です' if value.nil? # 開発者向け
  end
end
