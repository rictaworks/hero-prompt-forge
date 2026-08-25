import js from "@eslint/js";
import tseslint from "typescript-eslint";
import nextPlugin from "@next/eslint-plugin-next";
import reactHooks from "eslint-plugin-react-hooks";

/**
 * コード規約の検査です。
 *
 * FlatCompat（旧形式の読み替え）は使いません。ESLint 9 と組み合わせると
 * 設定の読み込み時に循環参照で落ちるためです。各プラグインを直接読み込みます。
 */
export default tseslint.config(
  {
    ignores: [".next/**", "node_modules/**", "out/**", "next-env.d.ts", "jest.config.ts"],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    plugins: {
      "@next/next": nextPlugin,
      "react-hooks": reactHooks,
    },
    rules: {
      ...nextPlugin.configs.recommended.rules,
      ...nextPlugin.configs["core-web-vitals"].rules,
      ...reactHooks.configs.recommended.rules,
    },
  },
  {
    rules: {
      // ネイティブの alert() / confirm() / prompt() をプロジェクト全体で禁止します。
      "no-restricted-globals": [
        "error",
        { name: "alert", message: "alert() は使用禁止です。画面上の表示で伝えてください。" },
        { name: "confirm", message: "confirm() は使用禁止です。画面上の確認で伝えてください。" },
        { name: "prompt", message: "prompt() は使用禁止です。画面上の入力欄を使ってください。" },
      ],
      "no-restricted-properties": [
        "error",
        { object: "window", property: "alert", message: "alert() は使用禁止です。" },
        { object: "window", property: "confirm", message: "confirm() は使用禁止です。" },
        { object: "window", property: "prompt", message: "prompt() は使用禁止です。" },
      ],
      // 例外を握りつぶす書き方を禁止します（フォールバック禁止）。
      "no-empty": ["error", { allowEmptyCatch: false }],
      // 暗黙のグローバル変数を禁止します。
      "no-implicit-globals": "error",
    },
  },
  {
    files: ["**/*.test.ts", "**/*.test.tsx"],
    languageOptions: {
      globals: {
        describe: "readonly",
        it: "readonly",
        expect: "readonly",
        afterEach: "readonly",
        beforeEach: "readonly",
        jest: "readonly",
        process: "readonly",
      },
    },
  },
);
