import { render, screen } from "@testing-library/react";

import {
  MissingResetAtError,
  QuotaPanel,
  RejectionPanel,
  marked,
  reasonsOf,
  resetAtOf,
  spellQuotaDay,
} from "@/components/exceptions";
import { ApiError } from "@/types/api";

/** 上限到達の失敗です。**契約は `details.reset_at` を必ず添えます。** */
function quotaError(details: Record<string, unknown> = { reset_at: "2026-08-28T03:00:00+09:00" }) {
  return new ApiError(429, {
    code: "quota_exhausted",
    message: "本日の生成枠を使い切りました。",
    next_action: "次回のリセットは 8月28日 03:00 です。",
    details,
  });
}

function rejectionError(reasons: unknown) {
  return new ApiError(422, {
    code: "forbidden_input",
    message: "権利に触れるおそれのある内容が含まれています。",
    next_action: "入力を書き換えて、もう一度お試しください。",
    details: { reasons },
  });
}

const REASON = {
  kind: "real_person",
  matched: "有名人",
  suggestion_key: "describe_person_by_role",
};

describe("上限到達", () => {
  // **次回のリセット時刻を必ず出します**（issue #76 の受け入れ条件）。
  it("次回のリセット時刻を出します", () => {
    render(
      <QuotaPanel
        message={quotaError().message}
        nextAction={quotaError().nextAction}
        resetAt="2026-08-28T03:00:00+09:00"
      />,
    );

    expect(screen.getByText("03:00")).toBeVisible();
  });

  it("日付も添えます", () => {
    render(
      <QuotaPanel message="m" nextAction="n" resetAt="2026-08-28T03:00:00+09:00" />,
    );

    expect(screen.getByText(/2026\/08\/28/)).toBeVisible();
  });

  // **消費の帰属（クォータ日）は、リセットの前日です**（requirements.md 4.4）。
  it("消費の帰属を出します", () => {
    render(
      <QuotaPanel message="m" nextAction="n" resetAt="2026-08-28T03:00:00+09:00" />,
    );

    expect(screen.getByText("2026/08/27")).toBeVisible();
  });

  it("API の文言をそのまま出します", () => {
    render(
      <QuotaPanel
        message="本日の生成枠を使い切りました。"
        nextAction="次回のリセットは 8月28日 03:00 です。"
        resetAt="2026-08-28T03:00:00+09:00"
      />,
    );

    expect(screen.getByText("本日の生成枠を使い切りました。")).toBeVisible();
    expect(screen.getByText("次回のリセットは 8月28日 03:00 です。")).toBeVisible();
  });

  it("閲覧と記録が続けられることを伝えます", () => {
    render(
      <QuotaPanel message="m" nextAction="n" resetAt="2026-08-28T03:00:00+09:00" />,
    );

    expect(screen.getByText(/上限に関係なく行えます/)).toBeVisible();
  });

  // **既定へ寄せません。** 時刻を出さない上限到達の画面を黙って出しません。
  it("時刻が無ければ、その場で失敗させます", () => {
    expect(() => resetAtOf(quotaError({}))).toThrow(MissingResetAtError);
  });

  it("時刻が文字列でなければ失敗させます", () => {
    expect(() => resetAtOf(quotaError({ reset_at: 12345 }))).toThrow(MissingResetAtError);
  });

  it("時刻があれば、その値を返します", () => {
    expect(resetAtOf(quotaError())).toBe("2026-08-28T03:00:00+09:00");
  });

  it("日時として読めなければ失敗させます", () => {
    expect(() => spellQuotaDay("こわれた値")).toThrow(MissingResetAtError);
  });
});

describe("差し戻し", () => {
  // **理由を必ず出します**（issue #71 の受け入れ条件）。
  it("見つかった種別の説明を出します", () => {
    render(
      <RejectionPanel message="m" nextAction="n" reasons={[REASON]} />,
    );

    expect(screen.getByText(/実在人物名の指定です/)).toBeVisible();
  });

  it("直し方を出します", () => {
    render(<RejectionPanel message="m" nextAction="n" reasons={[REASON]} />);

    expect(screen.getByText(/役割で書くと/)).toBeVisible();
  });

  it("見つかった語を出します", () => {
    render(<RejectionPanel message="m" nextAction="n" reasons={[REASON]} />);

    expect(screen.getByText("有名人")).toBeVisible();
  });

  // **送っていただいた文章に印を付けます**（`app-ui/degraded.html`）。
  it("送った文章に印を付けます", () => {
    render(
      <RejectionPanel
        message="m"
        nextAction="n"
        reasons={[REASON]}
        submitted="有名人を前面に出した構図にしたいです。"
      />,
    );

    expect(screen.getByText("を前面に出した構図にしたいです。", { exact: false })).toBeVisible();
  });

  // **取り出しの経路では、文章が残っていません。**
  it("文章が無ければ、その理由を伝えます", () => {
    render(<RejectionPanel message="m" nextAction="n" reasons={[REASON]} />);

    expect(screen.getByText(/文章を残していません/)).toBeVisible();
  });

  it("入力へ戻る操作を出せます", () => {
    render(
      <RejectionPanel message="m" nextAction="n" reasons={[REASON]} onFix={() => {}} />,
    );

    expect(screen.getByRole("button", { name: "入力を修正する" })).toBeVisible();
  });

  it("操作を渡さなければ出しません", () => {
    render(<RejectionPanel message="m" nextAction="n" reasons={[REASON]} />);

    expect(screen.queryByRole("button", { name: "入力を修正する" })).toBeNull();
  });

  // **形が違えば、何も返しません。** 推し量って埋めません。
  it("理由の形が違えば、何も取り出しません", () => {
    expect(reasonsOf(rejectionError("こわれた値"))).toEqual([]);
  });

  it("項目が欠けた理由は取り出しません", () => {
    expect(reasonsOf(rejectionError([{ kind: "real_person" }]))).toEqual([]);
  });

  it("形が正しい理由だけを取り出します", () => {
    expect(reasonsOf(rejectionError([REASON, { kind: "x" }]))).toEqual([REASON]);
  });
});

describe("見つかった語の印", () => {
  it("見つからない語には印を付けません", () => {
    expect(marked("落ち着いた事務所です。", [REASON])).toEqual(["落ち着いた事務所です。"]);
  });

  it("正規の表現で特別な意味を持つ文字も、そのまま探します", () => {
    const reason = { ...REASON, matched: "a.b" };

    expect(marked("axb を入れます。", [reason])).toEqual(["axb を入れます。"]);
  });
});
