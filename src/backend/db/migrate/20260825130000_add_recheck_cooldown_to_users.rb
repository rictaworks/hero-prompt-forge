# frozen_string_literal: true

# 手動再判定のクールダウンです。
#
# フォロー直後の判定漏れに備えて、利用者の操作で再判定できるようにします。
# ただし連続して要求されると判定サービスへの負荷になるため、
# 次に要求できる時刻を保持します。
class AddRecheckCooldownToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.datetime :recheck_available_at, comment: '次に手動再判定を要求できる時刻'
      t.datetime :plan_checked_at, comment: 'プラン値を最後に判定した時刻'
    end
  end
end
