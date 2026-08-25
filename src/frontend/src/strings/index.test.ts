import { MissingStringError, text } from "@/strings";

describe("strings", () => {
  it("文言を取り出せます", () => {
    expect(text("errors.unauthorized.message")).toBe("ログインが必要です。");
  });

  it("見つからない場合は例外にします", () => {
    expect(() => text("errors.unauthorized.unknown")).toThrow(MissingStringError);
  });

  it("途中の階層が無い場合も例外にします", () => {
    expect(() => text("errors.nothing.message")).toThrow(MissingStringError);
  });

  it("日本語の文言はすべてですます調で終わります", () => {
    const collect = (value: unknown): string[] =>
      typeof value === "string"
        ? [value]
        : typeof value === "object" && value !== null
          ? Object.values(value).flatMap(collect)
          : [];

    const all = collect(
      // 文言の一覧をたどるため、モジュール全体を対象にします。
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      require("@/strings/ja").strings,
    );

    // 製品名など日本語を含まない値は文ではないため、対象にしません。
    const sentences = all.filter((value) => /[぀-ゟ゠-ヿ一-鿿]/.test(value));

    expect(sentences.length).toBeGreaterThan(0);
    for (const value of sentences) {
      expect(value.endsWith("。")).toBe(true);
    }
  });
});
