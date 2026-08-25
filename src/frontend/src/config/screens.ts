/**
 * 画面の一覧です。
 *
 * 実装済みかどうかを `path` の有無で表します。実装していない画面へは
 * 導線を張りません（開いても何も無い状態を作らないためです）。
 * 画面を実装したら、その issue で `path` を埋めます。
 */
export interface Screen {
  /** モックの番号です。 */
  readonly no: string;
  /** 画面の識別子です。 */
  readonly key: ScreenKey;
  /** 実装済みの場合の移動先です。未実装は null です。 */
  readonly path: string | null;
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
  { no: "01", key: "landing", path: "/" },
  { no: "02", key: "projects", path: null },
  { no: "03", key: "newRequest", path: null },
  { no: "04", key: "generating", path: null },
  { no: "05", key: "result", path: null },
  { no: "06", key: "evaluation", path: null },
  { no: "07", key: "presets", path: null },
  { no: "08", key: "degraded", path: null },
  { no: "09", key: "admin", path: null },
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
  return screenOf(key).path !== null;
}
