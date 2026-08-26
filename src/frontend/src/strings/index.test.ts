import { MissingStringError, strings, text } from "@/strings";

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

  it("文の文言はすべてですます調で終わります", () => {
    // 画面の項目名（ボタン・見出しの語）は文ではないため、対象にしません。
    // 対象から外す場所は、ここに明示して増減を追えるようにします。
    //
    // **`labels` の下は、まとめて対象から外します。** 押せるものの名前・
    // 見出しの語・添え書きの置き場です（`src/strings/ja.ts`）。
    // **`labels` を句点回避の逃げ道にしません。** 文はここへ置きません。
    const LABEL_PREFIXES = [
      "app.title",
      "app.wordmark",
      "nav.",
      "errors.unexpected.traceLabel",
    ];

    const isLabel = (path: string): boolean =>
      path.split(".").includes("labels");

    // **問いかけも、ですます調です。** 句点ではなく疑問符で終わります。
    const ENDINGS = ["。", "？"];

    const collect = (value: unknown, path: string): [string, string][] =>
      typeof value === "string"
        ? [[path, value]]
        : typeof value === "object" && value !== null
          ? Object.entries(value).flatMap(([key, child]) =>
              collect(child, path ? `${path}.${key}` : key),
            )
          : [];

    const all = collect(strings, "");
    const sentences = all.filter(
      ([path, value]) =>
        /[぀-ゟ゠-ヿ一-鿿]/.test(value) &&
        !isLabel(path) &&
        !LABEL_PREFIXES.some((prefix) => path.startsWith(prefix)),
    );

    expect(sentences.length).toBeGreaterThan(0);
    for (const [path, value] of sentences) {
      const ends = ENDINGS.some((ending) => value.endsWith(ending));
      expect([path, ends]).toEqual([path, true]);
    }
  });

  // **`labels` を句点回避の逃げ道にしません。**
  it("labels の下は短い語だけです", () => {
    const collect = (value: unknown, path: string): [string, string][] =>
      typeof value === "string"
        ? [[path, value]]
        : typeof value === "object" && value !== null
          ? Object.entries(value).flatMap(([key, child]) =>
              collect(child, path ? `${path}.${key}` : key),
            )
          : [];

    const labels = collect(strings, "").filter(([path]) =>
      path.split(".").includes("labels"),
    );

    expect(labels.length).toBeGreaterThan(0);
    for (const [path, value] of labels) {
      expect([path, value.length <= 30, value.includes("。")]).toEqual([
        path,
        true,
        false,
      ]);
    }
  });
});
