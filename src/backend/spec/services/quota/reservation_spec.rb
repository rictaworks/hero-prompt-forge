# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Quota::Reservation do
  let(:user) { User.create!(x_user_id: '1234567890', display_name: 'あお') }
  let(:project) { Project.create!(user: user, industry: 'saas', style_family: 'photoreal') }
  let(:prompt_request) { PromptRequest.create!(project: project, target_model: 'midjourney') }
  # クォータ日 2026-08-25 のまん中です。
  let(:now) { Time.find_zone!('Asia/Tokyo').parse('2026-08-25 12:00:00') }

  describe '.reserve!' do
    it 'その日の枠を予約します' do
      consumption = described_class.reserve!(user: user, now: now)

      expect(consumption.quota_day).to eq(Date.new(2026, 8, 25))
      expect(consumption.status).to eq('reserved')
    end

    it '境界の前は前日の枠を使います' do
      early = Time.find_zone!('Asia/Tokyo').parse('2026-08-26 02:59:00')

      expect(described_class.reserve!(user: user, now: early).quota_day)
        .to eq(Date.new(2026, 8, 25))
    end

    it '同じ日に二度目は予約できません' do
      described_class.reserve!(user: user, now: now)

      expect { described_class.reserve!(user: user, now: now) }
        .to raise_error(described_class::ExhaustedError)
    end

    it '上限に達したときは次回のリセット時刻を添えます' do
      described_class.reserve!(user: user, now: now)

      expect { described_class.reserve!(user: user, now: now) }
        .to raise_error(described_class::ExhaustedError) { |error|
          expect(error.reset_at).to eq(Time.find_zone!('Asia/Tokyo').parse('2026-08-26 03:00:00'))
          expect(error.quota_day).to eq(Date.new(2026, 8, 25))
        }
    end

    it '確定済みでも二度目は予約できません' do
      described_class.reserve!(user: user, now: now).transition_to!('confirmed')

      expect { described_class.reserve!(user: user, now: now) }
        .to raise_error(described_class::ExhaustedError)
    end

    it '日が変われば予約できます' do
      described_class.reserve!(user: user, now: now)
      next_day = Time.find_zone!('Asia/Tokyo').parse('2026-08-26 03:00:00')

      expect(described_class.reserve!(user: user, now: next_day).quota_day)
        .to eq(Date.new(2026, 8, 26))
    end

    it '生成リクエストを結び付けられます' do
      consumption = described_class.reserve!(user: user, prompt_request: prompt_request, now: now)

      expect(consumption.prompt_request).to eq(prompt_request)
    end

    it '他人の生成リクエストへは結び付けられません' do
      stranger = User.create!(x_user_id: '5555555555', display_name: 'しろ')

      expect { described_class.reserve!(user: stranger, prompt_request: prompt_request, now: now) }
        .to raise_error(described_class::ForeignRequestError)
    end

    it '他人の生成リクエストを渡したときは枠を使いません' do
      stranger = User.create!(x_user_id: '5555555555', display_name: 'しろ')

      expect { described_class.reserve!(user: stranger, prompt_request: prompt_request, now: now) }
        .to raise_error(described_class::ForeignRequestError)
      expect(QuotaConsumption.where(user_id: stranger.id).count).to eq(0)
    end

    it '同じ生成リクエストの予約は繰り返し呼んでも増えません' do
      first = described_class.reserve!(user: user, prompt_request: prompt_request, now: now)
      second = described_class.reserve!(user: user, prompt_request: prompt_request, now: now)

      expect(second).to eq(first)
      expect(QuotaConsumption.where(user_id: user.id).count).to eq(1)
    end
  end

  describe '.settle!' do
    before { described_class.reserve!(user: user, prompt_request: prompt_request, now: now) }

    it '通常完了で確定します' do
      prompt_request.transition_to!('queued')
      prompt_request.transition_to!('generating')
      prompt_request.transition_to!('completed')

      described_class.settle!(prompt_request)

      expect(QuotaConsumption.find_by(prompt_request_id: prompt_request.id).status)
        .to eq('confirmed')
    end

    it '縮退完了でも確定します' do
      prompt_request.transition_to!('queued')
      prompt_request.transition_to!('generating')
      prompt_request.transition_to!('degraded_completed', degraded: true)

      described_class.settle!(prompt_request)

      expect(QuotaConsumption.find_by(prompt_request_id: prompt_request.id).status)
        .to eq('confirmed')
    end

    it '失敗で返還します' do
      prompt_request.transition_to!('queued')
      prompt_request.transition_to!('generating')
      prompt_request.transition_to!('failed')

      described_class.settle!(prompt_request)

      expect(QuotaConsumption.find_by(prompt_request_id: prompt_request.id).status)
        .to eq('refunded')
    end

    it '生成の途中では確定も返還もしません' do
      prompt_request.transition_to!('queued')

      expect { described_class.settle!(prompt_request) }
        .to raise_error(described_class::NotSettleableError)
    end

    it '予約が無ければ失敗します' do
      other = PromptRequest.create!(project: project, target_model: 'dalle')
      other.transition_to!('queued')
      other.transition_to!('generating')
      other.transition_to!('completed')

      expect { described_class.settle!(other) }.to raise_error(described_class::MissingReservationError)
    end
  end

  describe '返還のあとの作り直し' do
    it '同じ日にもう一度予約できます' do
      described_class.reserve!(user: user, prompt_request: prompt_request, now: now)
      prompt_request.transition_to!('queued')
      prompt_request.transition_to!('generating')
      prompt_request.transition_to!('failed')
      described_class.settle!(prompt_request)

      consumption = described_class.reserve!(user: user, prompt_request: prompt_request, now: now)

      expect(consumption.status).to eq('reserved')
      expect(QuotaConsumption.where(user_id: user.id).count).to eq(1)
    end

    it '作り直しても記録は増えません' do
      described_class.reserve!(user: user, now: now).transition_to!('refunded')

      described_class.reserve!(user: user, now: now)

      expect(QuotaConsumption.where(user_id: user.id).count).to eq(1)
    end
  end

  describe '禁止入力' do
    it '差し戻したリクエストは枠を使いません' do
      prompt_request.transition_to!('rejected', rejection_reason: 'forbidden_input')

      expect { described_class.settle!(prompt_request) }
        .to raise_error(described_class::MissingReservationError)
      expect(QuotaConsumption.where(user_id: user.id).count).to eq(0)
    end
  end

  describe '日をまたぐ再実行' do
    let(:next_day) { Time.find_zone!('Asia/Tokyo').parse('2026-08-26 12:00:00') }

    before do
      described_class.reserve!(user: user, prompt_request: prompt_request, now: now)
      prompt_request.transition_to!('queued')
      prompt_request.transition_to!('generating')
      prompt_request.transition_to!('failed')
      described_class.settle!(prompt_request)
    end

    it '翌日に取り直すと、その日の枠を使います' do
      consumption = described_class.reserve!(user: user, prompt_request: prompt_request,
                                             now: next_day)

      expect(consumption.quota_day).to eq(Date.new(2026, 8, 26))
      expect(consumption.status).to eq('reserved')
    end

    it '決着は当日の予約に当たります' do
      described_class.reserve!(user: user, prompt_request: prompt_request, now: next_day)
      prompt_request.transition_to!('queued')
      prompt_request.transition_to!('generating')
      prompt_request.transition_to!('completed')

      settled = described_class.settle!(prompt_request)

      expect(settled.quota_day).to eq(Date.new(2026, 8, 26))
      expect(settled.status).to eq('confirmed')
    end

    it '前日の返還済みの記録はそのまま残ります' do
      described_class.reserve!(user: user, prompt_request: prompt_request, now: next_day)
      prompt_request.transition_to!('queued')
      prompt_request.transition_to!('generating')
      prompt_request.transition_to!('completed')
      described_class.settle!(prompt_request)

      previous = QuotaConsumption.find_for(user, Date.new(2026, 8, 25))

      expect(previous.status).to eq('refunded')
    end
  end

  describe '返還のもとになった生成リクエストとの結び付き' do
    it '生成リクエストを渡さずに取り直しても、結び付きは消えません' do
      described_class.reserve!(user: user, prompt_request: prompt_request, now: now)
      prompt_request.transition_to!('queued')
      prompt_request.transition_to!('generating')
      prompt_request.transition_to!('failed')
      described_class.settle!(prompt_request)

      consumption = described_class.reserve!(user: user, now: now)

      expect(consumption.prompt_request_id).to eq(prompt_request.id)
    end
  end

  describe '保存できない理由が上限到達でない場合' do
    it '上限到達として隠しません' do
      allow(QuotaConsumption).to receive(:create!)
        .and_raise(ActiveRecord::RecordNotUnique, '別の理由です')

      expect { described_class.reserve!(user: user, now: now) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  # 決着が呼ばれないまま予約が残った状態で、別の日に同じ生成リクエストを
  # 取り直す場合です。一意索引（予約中 × 生成リクエスト）が保存を止めます。
  #
  # **索引が止めること自体は正しい判断です。問題は出方でした。**
  # データベースの例外がそのまま外へ出ると、呼び出す側（issue #55 の API）が
  # 自前の例外だけを捕まえる作りのときに 500 になり、索引名と鍵の値も漏れます。
  describe '決着が漏れた予約が別の日に残っている場合' do
    let(:next_day) { Time.find_zone!('Asia/Tokyo').parse('2026-08-26 12:00:00') }

    before do
      # 決着を呼ばないまま、前日の予約を残します。
      described_class.reserve!(user: user, prompt_request: prompt_request, now: now)
    end

    it '枠は残っているように見えます' do
      expect(described_class.remaining_for?(user, now: next_day)).to be(true)
    end

    it 'この持ち場の例外になります' do
      expect { described_class.reserve!(user: user, prompt_request: prompt_request, now: next_day) }
        .to raise_error(described_class::DanglingReservationError)
    end

    it '残っているクォータ日が例外から分かります' do
      expect { described_class.reserve!(user: user, prompt_request: prompt_request, now: next_day) }
        .to raise_error(described_class::DanglingReservationError) { |error|
          expect(error.quota_day).to eq(Date.new(2026, 8, 25))
          expect(error.prompt_request_id).to eq(prompt_request.id)
        }
    end

    it '索引名と鍵の値を外へ出しません' do
      expect { described_class.reserve!(user: user, prompt_request: prompt_request, now: next_day) }
        .to raise_error(described_class::DanglingReservationError) { |error|
          expect(error.message).not_to include('index_quota_consumptions')
          expect(error.message).not_to include('duplicate key')
        }
    end

    # **呼び出す側がトランザクションで包む形は、issue #55 で実際に使います。**
    # 保存点を作らないと、一意性の違反で外側のトランザクション全体が中断状態に
    # なり、続く問い合わせが `PG::InFailedSqlTransaction` で拒まれます。
    # 読み替えそのものが働かなくなります。
    it '呼び出す側がトランザクションで包んでも、読み替えが働きます' do
      expect do
        ActiveRecord::Base.transaction do
          described_class.reserve!(user: user, prompt_request: prompt_request, now: next_day)
        end
      end.to raise_error(described_class::DanglingReservationError)
    end

    it '返還すれば、翌日に取り直せます' do
      prompt_request.transition_to!('queued')
      prompt_request.transition_to!('generating')
      prompt_request.transition_to!('failed')
      described_class.settle!(prompt_request)

      consumption = described_class.reserve!(user: user, prompt_request: prompt_request,
                                             now: next_day)

      expect(consumption.quota_day).to eq(Date.new(2026, 8, 26))
    end
  end

  # **同じ日の作り直しでも、決着の漏れに当たります。**
  # PR #143 のレビューで見つかりました。返還済みの枠を取り直す経路
  # （`claim!`）は行に錠をかけるためにトランザクションを開きます。その中で
  # 一意性の違反が起きると、トランザクション全体が中断状態になり、
  # 理由を調べる問い合わせ自体が拒まれます。
  #
  # requirements.md 4.4 の「失敗したら当日中に作り直せます」が、まさに
  # この手順です。
  describe '返還済みの枠を取り直すときに、決着の漏れがある場合' do
    let(:next_day) { Time.find_zone!('Asia/Tokyo').parse('2026-08-26 12:00:00') }

    before do
      # 1 日目：決着を呼ばないまま予約を残します（決着の漏れ）。
      described_class.reserve!(user: user, prompt_request: prompt_request, now: now)
      # 2 日目：別の生成リクエストで予約し、失敗して返還します。
      other = PromptRequest.create!(project: project, target_model: 'dalle')
      described_class.reserve!(user: user, prompt_request: other, now: next_day)
      other.transition_to!('queued')
      other.transition_to!('generating')
      other.transition_to!('failed')
      described_class.settle!(other)
    end

    it '同じ日の作り直しで、この持ち場の例外になります' do
      expect { described_class.reserve!(user: user, prompt_request: prompt_request, now: next_day) }
        .to raise_error(described_class::DanglingReservationError)
    end

    it '残っているクォータ日が例外から分かります' do
      expect { described_class.reserve!(user: user, prompt_request: prompt_request, now: next_day) }
        .to raise_error(described_class::DanglingReservationError) { |error|
          expect(error.quota_day).to eq(Date.new(2026, 8, 25))
        }
    end

    it '索引名と鍵の値を外へ出しません' do
      expect { described_class.reserve!(user: user, prompt_request: prompt_request, now: next_day) }
        .to raise_error(described_class::DanglingReservationError) { |error|
          expect(error.message).not_to include('index_quota_consumptions')
          expect(error.message).not_to include('duplicate key')
        }
    end

    it '呼び出す側がトランザクションで包んでも、読み替えが働きます' do
      expect do
        ActiveRecord::Base.transaction do
          described_class.reserve!(user: user, prompt_request: prompt_request, now: next_day)
        end
      end.to raise_error(described_class::DanglingReservationError)
    end

    it '別の生成リクエストであれば、同じ日に取り直せます' do
      another = PromptRequest.create!(project: project, target_model: 'midjourney')

      consumption = described_class.reserve!(user: user, prompt_request: another, now: next_day)

      expect(consumption.status).to eq('reserved')
    end
  end

  # 上限到達の読み替えが、呼び出す側のトランザクションの中でも働くことです。
  #
  # **この節は、検証で止まる経路です。** 保存点が無くても通ります。
  # **保存点の効きを守るのは、「決着が漏れた予約」の 2 つの節です。**
  # そちらはデータベースの一意索引で止まるため、保存点が無いと
  # トランザクション全体が中断し、読み替えそのものが働かなくなります。
  # 実際のデータベースの違反に対して読み替えが働くことは、
  # `reservation_race_spec.rb` の「記録が無い状態から同時に予約したとき」で
  # 確かめています。
  describe '上限到達の読み替え' do
    it '呼び出す側がトランザクションで包んでも働きます' do
      described_class.reserve!(user: user, now: now)

      expect do
        ActiveRecord::Base.transaction do
          described_class.reserve!(user: user, now: now)
        end
      end.to raise_error(described_class::ExhaustedError)
    end

    it '包まれた中でも、次回のリセット時刻を添えます' do
      described_class.reserve!(user: user, now: now)

      expect do
        ActiveRecord::Base.transaction do
          described_class.reserve!(user: user, now: now)
        end
      end.to raise_error(described_class::ExhaustedError) { |error|
        expect(error.reset_at).to eq(Quota::QuotaDay.reset_at(Date.new(2026, 8, 25)))
      }
    end
  end

  # **黙って新しい方を選びません。**
  #
  # 予約中の記録は、一意索引（予約中 × 生成リクエスト）によって 1 件までです。
  # そのため、この状態はいまのデータベースでは作れません。**索引が守っている
  # 事実と、索引が外れたときに静かに間違えない事実の、両方を固定します。**
  describe '予約中の記録が複数ある場合' do
    before do
      described_class.reserve!(user: user, prompt_request: prompt_request, now: now)
      prompt_request.transition_to!('queued')
      prompt_request.transition_to!('generating')
      prompt_request.transition_to!('completed')
    end

    it 'データベースが 2 件目の予約中を受け付けません' do
      other = User.create!(x_user_id: '2222222222', display_name: 'しろ')

      # **モデルの検証をあえて通しません。** データベースの索引が止めることを
      # 確かめる例のためです。検証で止めてしまうと、索引の効きを見られません。
      expect do
        QuotaConsumption.insert_all!( # rubocop:disable Rails/SkipsModelValidations
          [{ user_id: other.id, quota_day: Date.new(2026, 8, 26),
             prompt_request_id: prompt_request.id, status: 'reserved',
             created_at: Time.current, updated_at: Time.current }]
        )
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it '万一 2 件見つかったら、決着を求められても失敗します' do
      found = QuotaConsumption.where(prompt_request_id: prompt_request.id, status: 'reserved')
      relation = instance_double(ActiveRecord::Relation, to_a: found.to_a * 2)
      allow(QuotaConsumption).to receive(:where)
        .with(prompt_request_id: prompt_request.id, status: 'reserved').and_return(relation)
      # **並べ方の指定には依存しません。** 照合の書き方を変えただけで
      # このテストが落ちると、実装の内部を固定したことになります。
      allow(relation).to receive(:order).and_return(relation)

      expect { described_class.settle!(prompt_request) }
        .to raise_error(described_class::AmbiguousReservationError)
    end
  end

  describe '.remaining_for?' do
    it '使っていなければ残っています' do
      expect(described_class.remaining_for?(user, now: now)).to be(true)
    end

    it '予約済みなら残っていません' do
      described_class.reserve!(user: user, now: now)

      expect(described_class.remaining_for?(user, now: now)).to be(false)
    end

    it '返還済みなら残っています' do
      described_class.reserve!(user: user, now: now).transition_to!('refunded')

      expect(described_class.remaining_for?(user, now: now)).to be(true)
    end
  end
end
