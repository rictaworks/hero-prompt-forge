# frozen_string_literal: true

require 'rails_helper'

# 返還済みの枠を、別々の接続から同時に取り直した場合の確かめです。
# 接続をまたぐため、テストごとのトランザクションを使いません。
#
# **関門を置いて、足並みをそろえてから取り直します。**
# スレッドの中で生成リクエストを作ると、接続の借り出しと書き込みの往復に
# 時間がかかり、競合の窓に入りません。**窓に入らないテストは、錠を外しても
# 赤くなりません。** 将来だれかが `with_lock` を外しても、CI が気づけない
# 状態になります（issue #132）。
#
# そのため、次の 2 つを守ります。
#
#   1. **生成リクエストは、スレッドの外で人数分だけ先に作ります。**
#      スレッドの中の処理を `reserve!` だけにします
#   2. **関門を置きます。** 各スレッドは接続を借りて 1 度だけ空の問い合わせを
#      投げ（接続を温めます）、印を積んで待機します。本体側が人数分の印を
#      受け取ってから関門を開き、全スレッドを同時に `reserve!` へ入れます
#
# この形であれば、錠を外した実装では 4 件とも成立し（確実に赤）、
# 錠のある実装では 1 件だけ成立します（確実に緑）。
RSpec.describe Quota::Reservation do
  self.use_transactional_tests = false

  # クォータ日 2026-08-25 のまん中です。
  let(:now) { Time.find_zone!('Asia/Tokyo').parse('2026-08-25 12:00:00') }
  let(:racers) { 4 }
  let(:x_user_id) { '7777777777' }

  # **前の実行の残りを片付けてから作ります。**
  # この例はテストごとのトランザクションを使いません。途中で失敗すると
  # 記録が残り、次の実行が同じ `x_user_id` の作成で落ちます
  # （PR #143 の整備で実測されました）。
  let!(:user) do
    clear_leftovers
    User.create!(x_user_id: x_user_id, display_name: 'くろ')
  end
  # **`let!` にします。** `let` のままだと最初の評価がスレッドの中で起こり、
  # 足並みがさらに崩れます。
  let!(:project) { Project.create!(user: user, industry: 'saas', style_family: 'photoreal') }

  after { clear_leftovers }

  # **測定軸の記録も片づけます**（issue #63）。
  # この試験はトランザクションの外で書きますので、残すと次の試験へ持ち越します。
  def clear_leftovers
    MetricEvent.delete_all
    User.where(x_user_id: x_user_id).find_each do |leftover|
      QuotaConsumption.where(user_id: leftover.id).find_each(&:destroy!)
      Project.where(user_id: leftover.id).find_each do |owned|
        PromptRequest.where(project_id: owned.id).find_each(&:destroy!)
        owned.destroy!
      end
      leftover.destroy!
    end
  end

  # 生成リクエストを、スレッドの外で人数分だけ先に作ります。
  def prepared_requests
    Array.new(racers) { PromptRequest.create!(project: project, target_model: 'midjourney') }
  end

  # 関門の前で待ち、開いたら一斉に取り直します。
  def racing_thread(request, results, ready, gate)
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute('select 1') # 接続を温めます
        ready << true
        gate.pop
        results << outcome_of(request)
      end
    end
  end

  def outcome_of(request)
    described_class.reserve!(user: user, prompt_request: request, now: now)
    :accepted
  rescue described_class::ExhaustedError
    :blocked
  end

  # 同時に取り直し、結果を集めます。
  def race
    results = Queue.new
    run_racers(results)

    Array.new(results.size) { results.pop }
  end

  # 関門の前に全員をそろえてから、いっせいに開きます。
  def run_racers(results)
    ready = Queue.new
    gate = Queue.new
    threads = prepared_requests.map { |request| racing_thread(request, results, ready, gate) }

    racers.times { ready.pop }
    racers.times { gate << true }
    threads.each(&:join)
  end

  describe '返還済みの枠を同時に取り直したとき' do
    before do
      QuotaConsumption.create!(user: user, quota_day: Quota::QuotaDay.of(now), status: 'refunded')
    end

    it '予約が成立するのは1件だけです' do
      outcomes = race

      expect(outcomes.count(:accepted)).to eq(1)
      expect(outcomes.count(:blocked)).to eq(racers - 1)
    end

    it '枠の記録は1件のままです' do
      race

      expect(QuotaConsumption.where(user_id: user.id).count).to eq(1)
    end
  end

  # **記録がまだ無い状態から同時に予約します。**
  # 先を越された側は、検証をすり抜けてデータベースの一意制約に当たります。
  # **上限到達の読み替えが、実際の一意性の違反に対して働くことを確かめます。**
  # 読み替えが働かないと、利用者へ理由の分からない失敗が返ります。
  describe '記録が無い状態から同時に予約したとき' do
    it '予約が成立するのは1件だけです' do
      outcomes = race

      expect(outcomes.count(:accepted)).to eq(1)
      expect(outcomes.count(:blocked)).to eq(racers - 1)
    end

    it '枠の記録は1件だけできます' do
      race

      expect(QuotaConsumption.where(user_id: user.id).count).to eq(1)
    end
  end
end
