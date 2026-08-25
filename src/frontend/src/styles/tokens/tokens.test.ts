import { readFileSync } from "node:fs";
import { join } from "node:path";

/**
 * デザイントークンの値が app-ui のモックと一致していることを固定します。
 * 値がずれると、実装した画面がモックと違う見た目になります。
 */
const REPO_ROOT = join(__dirname, "..", "..", "..", "..", "..");
const MOCK_TOKENS = join(
  REPO_ROOT,
  "app-ui",
  "_ds",
  "veyra-dragon-c89babbb-c5ca-488f-a767-e5ea1062d0f9",
  "tokens",
);
const APP_TOKENS = __dirname;

// 変数を定義するトークンです。
const VARIABLE_FILES = ["colors", "typography", "spacing", "effects"];
// base.css は変数ではなく土台の指定です。内容そのものを比べます。
const PLAIN_FILES = ["base"];

function variables(css: string): Map<string, string> {
  const found = new Map<string, string>();
  const pattern = /(--[\w-]+)\s*:\s*([^;]+);/g;
  let match;
  while ((match = pattern.exec(css)) !== null) {
    found.set(match[1], match[2].replace(/\/\*.*?\*\//g, "").trim());
  }
  return found;
}

describe("デザイントークン", () => {
  for (const name of VARIABLE_FILES) {
    it(`${name} の値が app-ui と一致します`, () => {
      const mock = variables(readFileSync(join(MOCK_TOKENS, `${name}.css`), "utf8"));
      const app = variables(readFileSync(join(APP_TOKENS, `${name}.css`), "utf8"));

      expect(app.size).toBeGreaterThan(0);
      expect([...app.entries()]).toEqual([...mock.entries()]);
    });
  }

  for (const name of PLAIN_FILES) {
    it(`${name} の内容が app-ui と一致します`, () => {
      const mock = readFileSync(join(MOCK_TOKENS, `${name}.css`), "utf8").trim();
      const app = readFileSync(join(APP_TOKENS, `${name}.css`), "utf8").trim();

      expect(app.length).toBeGreaterThan(0);
      expect(app).toBe(mock);
    });
  }

  it("書体はトークンの変数から割り当てます", () => {
    const fonts = variables(readFileSync(join(APP_TOKENS, "fonts.css"), "utf8"));

    expect(fonts.get("--font-display")).toBe("var(--font-montserrat), sans-serif");
    expect(fonts.get("--font-body")).toBe("var(--font-noto-sans-jp), sans-serif");
  });
});
