/**
 * 画面の一覧です。
 *
 * 実装していない画面へは導線を張りません（開いても何も無い状態を作らない
 * ためです）。画面を実装したら、その issue で `implemented` を立てます。
 *
 * **固定の入口を持つ画面と、識別子で決まる画面を分けます。** 生成中（04）・
 * 結果（05）・評価メモ（06）は、識別子を含む場所（requests の下）ですので、
 * **一覧から張れる固定の入口を持ちません。** 実装済みかどうかを `path` の
 * 有無で表すと、この 3 画面が永久に「未実装」になります。
 */
export interface Screen {
  /** モックの番号です。 */
  readonly no: string;
  /** 画面の識別子です。 */
  readonly key: ScreenKey;
  /** 一覧から張れる固定の入口です。**識別子で決まる画面は持ちません。** */
  readonly path: string | null;
  /** 実装済みかどうかです。 */
  readonly implemented: boolean;
}

export type ScreenKey =
  | "landing"
  | "projects"
  | "newRequest"
  | "generating"
  | "result"
  | "evaluation"
  | "presets"
  | "degraded"
  | "admin";

export const SCREENS: readonly Screen[] = [
  { no: "01", key: "landing", path: "/", implemented: true },
  { no: "02", key: "projects", path: "/projects", implemented: true },
  { no: "03", key: "newRequest", path: "/requests/new", implemented: true },
  { no: "04", key: "generating", path: null, implemented: true },
  { no: "05", key: "result", path: null, implemented: true },
  { no: "06", key: "evaluation", path: null, implemented: true },
  { no: "07", key: "presets", path: "/presets", implemented: true },
  // 縮退・エラー（08）は、生成中（04）の画面が状態に応じて出します。
  { no: "08", key: "degraded", path: null, implemented: true },
  // 管理（09）は開発者用です。**一般の利用者の画面に導線を出しません。**
  { no: "09", key: "admin", path: null, implemented: false },
] as const;

export class UnknownScreenError extends Error {}

export function screenOf(key: ScreenKey): Screen {
  const screen = SCREENS.find((s) => s.key === key);
  if (!screen) {
    throw new UnknownScreenError(`未定義の画面です: ${key}`); // 開発者向け
  }
  return screen;
}

/** 実装済みかどうかを返します。 */
export function isImplemented(key: ScreenKey): boolean {
  return screenOf(key).implemented;
}

/** 一覧から張れる入口を返します。**張れない場合は空です。** */
export function linkTo(key: ScreenKey): string | null {
  const screen = screenOf(key);
  return screen.implemented ? screen.path : null;
}
