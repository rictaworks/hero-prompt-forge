import {
  EMPTY_FORM,
  inputsOf,
  validate,
  type FormState,
} from "@/components/requests/NewRequestForm";

/** 必須の 3 項目だけを埋めた入力です。 */
function filled(overrides: Partial<FormState> = {}): FormState {
  return {
    ...EMPTY_FORM,
    industry: "saas",
    styleFamily: "photoreal",
    targetModel: "midjourney",
    ...overrides,
  };
}

describe("入力フォームの検査", () => {
  it("必須の 3 項目が空なら、3 件とも止めます", () => {
    const found = validate(EMPTY_FORM);

    expect(Object.keys(found).sort()).toEqual([
      "industry",
      "styleFamily",
      "targetModel",
    ]);
  });

  it("必須の 3 項目がそろえば通します", () => {
    expect(validate(filled())).toEqual({});
  });

  it("業種だけが空なら、業種だけを止めます", () => {
    const found = validate(filled({ industry: "" }));

    expect(Object.keys(found)).toEqual(["industry"]);
  });

  it("サービス概要が 1000 文字を越えれば止めます", () => {
    const found = validate(filled({ serviceSummary: "あ".repeat(1001) }));

    expect(found.serviceSummary).toBeDefined();
  });

  it("サービス概要が 1000 文字ちょうどなら通します", () => {
    const found = validate(filled({ serviceSummary: "あ".repeat(1000) }));

    expect(found.serviceSummary).toBeUndefined();
  });

  it("ブランドカラーの書き方が違えば止めます", () => {
    const found = validate(filled({ brandColorFirst: "青" }));

    expect(found.brandColorFirst).toBeDefined();
  });

  it("ブランドカラーが空なら、書き方を問いません", () => {
    expect(validate(filled({ brandColorFirst: "" }))).toEqual({});
  });

  it("2 色目の書き方だけが違う場合も止めます", () => {
    const found = validate(
      filled({ brandColorFirst: "#123456", brandColorSecond: "#12345" }),
    );

    expect(found.brandColorSecond).toBeDefined();
  });
});

describe("送る形への直し方", () => {
  it("必須の 3 項目と既定値を送ります", () => {
    expect(inputsOf(filled())).toEqual({
      industry: "saas",
      style_family: "photoreal",
      target_model: "midjourney",
      copy_space_position: "left",
      aspect_ratio: "16:9",
    });
  });

  it("空の任意項目は送りません", () => {
    const inputs = inputsOf(filled());

    expect(inputs.brand_tone).toBeUndefined();
    expect(inputs.service_summary).toBeUndefined();
    expect(inputs.brand_colors).toBeUndefined();
  });

  it("入れた任意項目だけを送ります", () => {
    const inputs = inputsOf(
      filled({
        brandTone: "trust",
        serviceSummary: "落ち着いた事務所です。",
        brandColorFirst: "#123456",
      }),
    );

    expect(inputs.brand_tone).toBe("trust");
    expect(inputs.service_summary).toBe("落ち着いた事務所です。");
    expect(inputs.brand_colors).toEqual(["#123456"]);
  });

  it("2 色を入れれば 2 色とも送ります", () => {
    const inputs = inputsOf(
      filled({ brandColorFirst: "#123456", brandColorSecond: "#abcdef" }),
    );

    expect(inputs.brand_colors).toEqual(["#123456", "#abcdef"]);
  });
});
