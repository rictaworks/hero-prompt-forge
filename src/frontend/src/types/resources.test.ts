import { strings } from "@/strings";
import {
  ASPECT_RATIOS,
  BRAND_TONES,
  COPY_SPACE_POSITIONS,
  INDUSTRIES,
  REQUEST_STATUSES,
  STYLE_FAMILIES,
  TARGET_MODELS,
} from "@/types/resources";

/**
 * 選択肢と呼び名の対応です（PR #174 のレビュー・要修正 6）。
 *
 * **呼び名を 1 つ落とすと、画面全体が落ちます。** `spellChoice()` が
 * `MissingStringError` を投げるためです。**落ちたことに気づける唯一の場所が
 * ここです。**
 */
describe("選択肢の呼び名", () => {
  const GROUPS: ReadonlyArray<[string, readonly string[]]> = [
    ["industry", INDUSTRIES],
    ["styleFamily", STYLE_FAMILIES],
    ["targetModel", TARGET_MODELS],
    ["brandTone", BRAND_TONES],
    ["copySpacePosition", COPY_SPACE_POSITIONS],
    ["aspectRatio", ASPECT_RATIOS],
    ["status", REQUEST_STATUSES],
  ];

  for (const [group, values] of GROUPS) {
    it(`${group}：すべての値に呼び名があります`, () => {
      const labels = (strings.choices as Record<string, Record<string, string>>)[group];

      expect(Object.keys(labels).sort()).toEqual([...values].sort());
    });
  }

  it("呼び名の組は、選択肢の数だけあります", () => {
    const groups = Object.keys(strings.choices);

    // **構図の別（`compositionType`）は選択肢ではありません。** 出力の種別です。
    expect(groups.sort()).toEqual(
      [...GROUPS.map(([group]) => group), "compositionType"].sort(),
    );
  });
});
