import { ApiError, isApiErrorResponse } from "@/types/api";

describe("api", () => {
  it("失敗の形を判定します", () => {
    expect(
      isApiErrorResponse({
        error: { code: "a", message: "b", next_action: "c" },
      }),
    ).toBe(true);
  });

  it("項目が欠けていれば失敗の形とみなしません", () => {
    expect(isApiErrorResponse({ error: { code: "a", message: "b" } })).toBe(false);
  });

  it("失敗の形でない値を判定します", () => {
    expect(isApiErrorResponse({ id: 1 })).toBe(false);
    expect(isApiErrorResponse(null)).toBe(false);
  });

  it("例外として扱えます", () => {
    const error = new ApiError(429, {
      code: "quota_exhausted",
      message: "本日の生成枠を使い切りました。",
      next_action: "次回のリセットをお待ちください。",
    });

    expect(error.status).toBe(429);
    expect(error.code).toBe("quota_exhausted");
    expect(error.message).toBe("本日の生成枠を使い切りました。");
    expect(error.nextAction).toBe("次回のリセットをお待ちください。");
  });
});
