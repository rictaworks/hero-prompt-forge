import { text } from "@/strings";

/**
 * 画面に出す形へ整えます。
 *
 * **書式を画面へ直書きしません。** 呼び名と区切りは設定から引きます。
 */

/** JST の日時を、画面に出す形へ整えます。 */
export function spellDateTime(value: string): string {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new RangeError(`日時として読めません: ${value}`); // 開発者向け
  }
  return new Intl.DateTimeFormat("ja-JP", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(parsed);
}

/** 選択肢の値を、画面に出す呼び名へ直します。 */
export function spellChoice(group: string, value: string): string {
  return text(`choices.${group}.${value}`);
}
