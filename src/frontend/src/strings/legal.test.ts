import { legal } from "@/strings/legal";
import { strings } from "@/strings";

/**
 * 法務ページの文言です（issue #171、#172）。
 *
 * **仕様と食い違わないことを、ここで検めます。** requirements.md 5.3 は、
 * 保持する個人関連情報を **X のユーザー ID と表示名のみ**と定めています。
 */
describe("法務ページの文言", () => {
  const DOCUMENTS = ["terms", "privacy", "commerce"] as const;

  /** 本文の段落をすべて集めます。 */
  function paragraphs(): string[] {
    return DOCUMENTS.flatMap((key) => [
      legal[key].intro,
      ...legal[key].articles.flatMap((article) => [...article.paragraphs]),
    ]);
  }

  it("3 つの文書をすべて持ちます", () => {
    expect(Object.keys(legal).sort()).toEqual(["commerce", "labels", "privacy", "terms"]);
  });

  for (const key of DOCUMENTS) {
    it(`${key}：条が 1 つ以上あります`, () => {
      expect(legal[key].articles.length).toBeGreaterThan(0);
    });

    it(`${key}：どの条にも段落があります`, () => {
      for (const article of legal[key].articles) {
        expect([article.labels.heading, article.paragraphs.length > 0]).toEqual([
          article.labels.heading,
          true,
        ]);
      }
    });
  }

  // **URL を書きません。** 宛先が変わったときに、本文へ触れずに済みます。
  it("本文に URL を書きません", () => {
    for (const paragraph of paragraphs()) {
      expect([paragraph, /https?:\/\//.test(paragraph)]).toEqual([paragraph, false]);
    }
  });

  // **1 つの段落は 1 つの段落です。** 途中で改行を入れません。
  it("段落の途中で改行しません", () => {
    for (const paragraph of paragraphs()) {
      expect([paragraph, paragraph.includes("\n")]).toEqual([paragraph, false]);
    }
  });

  // **保持する情報は、X のユーザー ID と表示名だけです**（requirements.md 5.3）。
  it("取得しない情報を、取得しないと書いています", () => {
    const text = paragraphs().join("");

    expect(text).toContain("メールアドレス・住所・電話番号は取得しません。");
  });

  it("保持する情報を、X のユーザー ID と表示名だけと書いています", () => {
    const text = paragraphs().join("");

    expect(text).toContain("X のユーザー ID と表示名だけです。");
  });

  // **reCAPTCHA の利用と送信先を書きます**（issue #171）。
  it("reCAPTCHA の利用を書いています", () => {
    expect(paragraphs().join("")).toContain("reCAPTCHA");
  });

  it("送信先が Google であることを書いています", () => {
    const text = legal.privacy.articles
      .flatMap((article) => [...article.paragraphs])
      .join("");

    expect(text).toContain("Google");
  });

  // **`remoteip` を送らないことと、その理由を書きます**（issue #171）。
  it("要求元のアドレスを送らないと書いています", () => {
    const text = legal.privacy.articles
      .flatMap((article) => [...article.paragraphs])
      .join("");

    expect(text).toContain("remoteip");
    expect(text).toContain("この項目は任意です。本サービスは、この項目を送りません。");
  });

  // **Cookie の利用を書きます**（issue #172）。
  it("Cookie の利用を書いています", () => {
    expect(paragraphs().join("")).toContain("hpf_session");
  });

  // **生成物の扱いを書きます**（issue #172）。
  it("プロンプトの権利が利用者へ帰属すると書いています", () => {
    const text = legal.terms.articles.flatMap((article) => [...article.paragraphs]).join("");

    expect(text).toContain("生成したプロンプトの権利は、利用者の方に帰属します。");
  });

  it("生成画像の責任の所在を書いています", () => {
    const text = legal.terms.articles.flatMap((article) => [...article.paragraphs]).join("");

    expect(text).toContain("利用者の方が負うものとします。");
  });

  // **無償ですので、表示義務がないことを書きます**（issue #172）。
  it("特定商取引法の表示義務がないことを書いています", () => {
    expect(legal.commerce.intro).toContain("義務はありません");
  });

  // **連絡先に個人名を使いません**（CLAUDE.md）。
  it("連絡先は info@rictaworks.jp です", () => {
    expect(legal.labels.contactValue).toBe("info@rictaworks.jp");
  });

  // **文言の木に載せます。** 載せないと、ですます調の検査が効きません。
  it("文言の木から引けます", () => {
    expect(strings.legal).toBe(legal);
  });
});
