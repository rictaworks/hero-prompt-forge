import { traceError, traceInfo, traceStep } from "@/lib/logger";

describe("logger", () => {
  it("処理の名前と文脈を記録します", () => {
    const info = jest.spyOn(console, "info").mockImplementation(() => {});

    traceInfo("生成", { requestId: 1 });

    expect(info).toHaveBeenCalledWith('[trace] 生成 requestId=1');
    info.mockRestore();
  });

  it("失敗を記録します", () => {
    const error = jest.spyOn(console, "error").mockImplementation(() => {});

    traceError("生成", new Error("壊れています"), { requestId: 2 });

    expect(error).toHaveBeenCalledWith(
      '[trace] 生成 失敗 requestId=2 error=Error: 壊れています',
    );
    error.mockRestore();
  });

  it("戻り値をそのまま返します", async () => {
    jest.spyOn(console, "info").mockImplementation(() => {});

    await expect(traceStep("生成", {}, async () => "値")).resolves.toBe("値");
  });

  it("例外を握りつぶさず投げ直します", async () => {
    jest.spyOn(console, "info").mockImplementation(() => {});
    jest.spyOn(console, "error").mockImplementation(() => {});

    await expect(
      traceStep("生成", { requestId: 3 }, async () => {
        throw new Error("失敗");
      }),
    ).rejects.toThrow("失敗");
  });
});
