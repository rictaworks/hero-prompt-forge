import { strings } from "@/strings/ja";

export { strings };
export type { Strings } from "@/strings/ja";

export class MissingStringError extends Error {}

/**
 * 文言を取り出します。
 *
 * 見つからない場合は例外にします。既定値や識別子をそのまま表示すると、
 * 文言の入れ忘れに気づけないためです。
 *
 * @example text("errors.unauthorized.message")
 */
export function text(path: string): string {
  const value = path
    .split(".")
    .reduce<unknown>(
      (acc, key) =>
        typeof acc === "object" && acc !== null
          ? (acc as Record<string, unknown>)[key]
          : undefined,
      strings,
    );

  if (typeof value !== "string") {
    throw new MissingStringError(`文言が見つかりません: ${path}`);
  }
  return value;
}
