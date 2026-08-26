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
      // モックの見出しです（`app-ui/index.html`）。**体言止めです。**
      // 句点で終わりますが、述語を持ちませんので `labels` へ置けません。
      // **モックを書き換えませんので、ここで明示して外します。**
      "landing.contact.title",
    ];

    const isLabel = (path: string): boolean =>
      path.split(".").includes("labels");

    // **語尾で見ます。** 終わりの記号だけを見ると、「だ・である調」が
    // 句点付きで素通りします（PR #170 のレビューで実測されました）。
    //
    // **問いかけも、ですます調です。** 句点ではなく疑問符で終わります。
    const ENDINGS = [
      "です。",
      "ます。",
      "ません。",
      "でした。",
      "ました。",
      "ください。",
      "ますか？",
      "ですか？",
      "できますか？",
    ];

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
  //
  // **述語を含む語を置きません。** 長さと句点の有無だけでは、
  // 「だ・である調」の短い文が素通りします（PR #170 のレビューより）。
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

    // 文であることを示す語尾です。**`labels` はここで終わりません。**
    //
    // **「含む」ではなく「終わる」で見ます。** 「フォロワーであること」の
    // ような名詞のまとまりは、条件の言い表し方として正しいものです。
    const PREDICATE_ENDINGS = [
      "です",
      "ます",
      "ません",
      "でした",
      "ました",
      "ください",
      "だ",
      "である",
      "する",
      "した",
      "ない",
      "無い",
    ];

    expect(labels.length).toBeGreaterThan(0);
    for (const [path, value] of labels) {
      const hasPredicate = PREDICATE_ENDINGS.some((word) => value.endsWith(word));

      expect([path, value.length <= 30, value.includes("。"), hasPredicate]).toEqual([
        path,
        true,
        false,
        false,
      ]);
    }
  });
});
