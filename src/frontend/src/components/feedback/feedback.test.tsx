import { render, screen } from "@testing-library/react";

import {
  Banner,
  ErrorNotice,
  UnexpectedErrorNotice,
} from "@/components/feedback";
import { ApiError } from "@/types/api";

describe("Banner", () => {
  it("題と本文を表示します", () => {
    render(
      <Banner kind="notice" title="DAILY QUOTA REACHED">
        本日の生成枠を使い切りました。
      </Banner>,
    );

    expect(screen.getByText("DAILY QUOTA REACHED")).toBeVisible();
    expect(screen.getByText("本日の生成枠を使い切りました。")).toBeVisible();
  });

  it("次に行う操作を表示します", () => {
    render(
      <Banner
        kind="notice"
        title="DAILY QUOTA REACHED"
        nextAction="次回のリセットは 03:00 です。"
      >
        本日の生成枠を使い切りました。
      </Banner>,
    );

    expect(screen.getByText("次回のリセットは 03:00 です。")).toBeVisible();
  });

  it("読み上げに伝わる形で表示します", () => {
    render(
      <Banner kind="degraded" title="DEGRADED MODE">
        辞書のみで合成しました。
      </Banner>,
    );

    expect(screen.getByRole("status")).toBeVisible();
  });
});

describe("ErrorNotice", () => {
  it("受け取った文言をそのまま表示します", () => {
    const error = new ApiError(429, {
      code: "quota_exhausted",
      message: "本日の生成枠を使い切りました。",
      next_action: "次回のリセットは 2026-08-26T03:00:00+09:00 です。",
    });

    render(<ErrorNotice error={error} />);

    expect(screen.getByText("本日の生成枠を使い切りました。")).toBeVisible();
    expect(
      screen.getByText("次回のリセットは 2026-08-26T03:00:00+09:00 です。"),
    ).toBeVisible();
  });

  it("次に行う操作を必ず表示します", () => {
    const error = new ApiError(422, {
      code: "forbidden_input",
      message: "禁止された入力が含まれています。",
      next_action: "該当箇所を修正して再送信してください。",
    });

    render(<ErrorNotice error={error} />);

    expect(
      screen.getByText("該当箇所を修正して再送信してください。"),
    ).toBeVisible();
  });
});

describe("UnexpectedErrorNotice", () => {
  it("想定外でも次に行う操作を示します", () => {
    render(<UnexpectedErrorNotice />);

    expect(screen.getByRole("status")).toBeVisible();
    expect(
      screen.getByText(/時間をおいて、もう一度お試しください。/),
    ).toBeVisible();
  });

  it("追跡の識別子を伝えられます", () => {
    render(<UnexpectedErrorNotice traceId="abc123" />);

    expect(screen.getByText(/abc123/)).toBeVisible();
  });
});
