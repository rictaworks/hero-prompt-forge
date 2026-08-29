"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import { Banner } from "@/components/feedback";
import { Button } from "@/components/ui";
import { spellDateTime } from "@/lib/format";
import { text } from "@/strings";
import type { ApiError } from "@/types/api";
import type { ForbiddenReason } from "@/types/resources";
import styles from "./exceptions.module.css";

/**
 * 上限到達と、禁止入力による差し戻しの伝え方です（issue #71、#76）。
 *
 * 体裁は `app-ui/degraded.html` に合わせます。**モックを書き換えません。**
 *
 * **曖昧なエラーを出しません。** 何が起きたかと、次に行う操作を必ず示します。
 * **文言は、API が返したものをそのまま出します。** ここで言い換えません。
 *
 * **ネイティブの警告表示（alert 等）を使いません**（CLAUDE.md）。
 */

export class MissingResetAtError extends Error {}

export interface QuotaPanelProps {
  /** 利用者に見せる文言です。 */
  message: string;
  /** 次に行う操作です。**次回のリセット時刻を含みます。** */
  nextAction: string;
  /**
   * 次回のリセット時刻です。**契約が `details.reset_at` に必ず添えます。**
   *
   * **無い場合は、その場で失敗させます**（PR #174 のレビュー・提案 22）。
   * 既定へ寄せると、時刻を出さない上限到達の画面が黙って出ます。
   */
  resetAt: string;
  /**
   * 使い切った枠の状態です（`details.status`）。**`confirmed` のときだけ、
   * モックの3行目「状態」を出します**（issue #183、`app-ui/degraded.html`）。
   *
   * `reserved`（前の生成がまだ進行中）は、まだ完了していないという意味で
   * 「confirmed（完了により確定）」と表示すると誤りになるため出しません。
   * モックはこの区別を持たない（確定した1例だけを示す）ため、無い場合の
   * 見せ方は実装側で決めています。
   */
  status?: string;
  /**
   * 本日確定した生成リクエストの識別子です（`details.result_prompt_request_id`）。
   *
   * **`status` が `confirmed` のときだけ添えられます。** ある場合だけ、
   * 「本日の結果を見る」を出し、結果画面（`/requests/:id/result`）へ導きます。
   */
  resultRequestId?: number;
}

/**
 * 上限到達です（requirements.md 4.4）。
 *
 * 体裁は `app-ui/degraded.html` の「上限到達」に合わせます。
 *
 * **次回のリセット時刻を必ず出します。** 曖昧なエラーを返しません。
 *
 * **消費の帰属（クォータ日）も出します。** リセットの時刻は日本時間の 3:00 で、
 * **午前 0 時ではありません。** どの日ぶんを使ったのかが分からないと、
 * 「昨日使ったのに、まだ使えないのはなぜか」が説明できません。
 */
export function QuotaPanel({
  message,
  nextAction,
  resetAt,
  status,
  resultRequestId,
}: QuotaPanelProps) {
  const reset = spellDateTime(resetAt);
  const quotaDay = spellQuotaDay(resetAt);

  return (
    <section className={styles.block}>
      <Banner
        kind="notice"
        title={text("exceptions.labels.quotaEyebrow")}
        nextAction={nextAction}
      >
        {message}
      </Banner>

      <div className={`${styles.panel} ${styles.split}`}>
        <div>
          <div className={styles.label}>{text("exceptions.labels.quotaResetHeading")}</div>
          <div className={styles.resetTime}>{spellTime(resetAt)}</div>
          <div className={styles.resetRule} />
          <span className={styles.resetNote}>
            {`${text("exceptions.labels.quotaZone")}${text("common.labels.separator")}${reset}`}
          </span>
        </div>
        <div className={styles.facts}>
          <div className={styles.factsRow}>
            <span className={styles.factsKey}>
              {text("exceptions.labels.quotaDayHeading")}
            </span>
            <span className={styles.factsValue}>{quotaDay}</span>
          </div>
          {status === "confirmed" ? (
            <div className={styles.factsRow}>
              <span className={styles.factsKey}>
                {text("exceptions.labels.quotaStateHeading")}
              </span>
              <span className={styles.factsValue}>
                {text("exceptions.labels.quotaStateConfirmed")}
              </span>
            </div>
          ) : null}
          <div className={styles.factsRow}>
            <span className={styles.factsKey}>
              {text("exceptions.labels.quotaRefundHeading")}
            </span>
            <span className={styles.factsValue}>
              {text("exceptions.labels.quotaRefundValue")}
            </span>
          </div>
          <p className={styles.factsNote}>{text("exceptions.quotaNote")}</p>
          <div className={styles.actions}>
            {resultRequestId !== undefined ? (
              <Button
                variant="outline"
                icon="chevron-right"
                href={`/requests/${resultRequestId}/result`}
              >
                {text("exceptions.labels.resultLink")}
              </Button>
            ) : null}
            <Link className={styles.actionLink} href="/projects">
              {text("exceptions.labels.historyLink")}
            </Link>
          </div>
        </div>
      </div>
    </section>
  );
}

export interface RejectionPanelProps {
  message: string;
  nextAction: string;
  /** 見つかった理由です。**取り出しの経路では空です。** */
  reasons: ForbiddenReason[];
  /**
   * 送っていただいた文章です。**見つかった語に印を付けて出します。**
   *
   * **取り出しの経路では渡しません。** 差し戻した記録に残っていません
   * （`SPEC/api/README.md`）。
   */
  submitted?: string;
  /** 入力へ戻る操作です。省いた場合は出しません。 */
  onFix?: () => void;
}

/**
 * 禁止入力による差し戻しです（requirements.md 4.1 の 1）。
 *
 * **枠を使っていないことは、API の文言が伝えます。**
 *
 * **見つかった語は、要求した本人が送った入力の写しです**（`SPEC/api/README.md`）。
 * **React が逃がしますので、そのまま描いて差し支えありません。**
 */
export function RejectionPanel({
  message,
  nextAction,
  reasons,
  submitted,
  onFix,
}: RejectionPanelProps) {
  return (
    <section className={styles.block}>
      <Banner
        kind="rejected"
        title={text("exceptions.labels.rejectedEyebrow")}
        nextAction={nextAction}
      >
        {message}
      </Banner>

      {reasons.length > 0 ? (
        <div className={styles.panel}>
          <div className={styles.label}>
            {text("exceptions.labels.rejectedDetectedHeading")}
          </div>
          {submitted === undefined ? (
            <p className={styles.absent}>{text("exceptions.rejectedInputAbsent")}</p>
          ) : (
            <p className={styles.quote}>
              {marked(submitted, reasons)}
            </p>
          )}
          <div className={styles.reasons}>
            {reasons.map((reason, index) => (
              <div key={`reason-${index}`} className={styles.reasonsRow}>
                <span className={styles.reasonsKey}>
                  {`${text("exceptions.labels.rejectedReasonHeading")} ${String(index + 1).padStart(2, "0")}`}
                </span>
                <span className={styles.reasonsValue}>
                  <span className={styles.flag}>{reason.matched}</span>
                  {text(`exceptions.reasons.${reason.kind}`)}
                </span>
              </div>
            ))}
            {reasons.map((reason, index) => (
              <div key={`suggestion-${index}`} className={styles.reasonsRow}>
                <span className={styles.reasonsKey}>
                  {text("exceptions.labels.rejectedSuggestionHeading")}
                </span>
                <span className={styles.reasonsValue}>
                  {text(`exceptions.suggestions.${reason.suggestion_key}`)}
                </span>
              </div>
            ))}
          </div>
          {onFix ? (
            <div className={styles.submit}>
              <Button variant="submit" onClick={onFix} fullWidth>
                {text("exceptions.labels.rejectedFix")}
              </Button>
            </div>
          ) : null}
        </div>
      ) : null}
    </section>
  );
}

/**
 * 送っていただいた文章へ、見つかった語の印を付けます。
 *
 * **利用者が送った文字です。** React が逃がしますので、そのまま描いて
 * 差し支えありません（`SPEC/api/README.md`）。
 *
 * **見つからなかった語は、印を付けません。** 推し量って場所を決めません。
 */
export function marked(submitted: string, reasons: ForbiddenReason[]): ReactNode[] {
  const words = [...new Set(reasons.map((reason) => reason.matched))].filter(
    (word) => word !== "" && submitted.includes(word),
  );

  if (words.length === 0) {
    return [submitted];
  }

  const pattern = new RegExp(`(${words.map(escaped).join("|")})`);

  return submitted.split(pattern).map((part, index) =>
    words.includes(part) ? (
      <span key={`flag-${index}`} className={styles.flag}>
        {part}
      </span>
    ) : (
      part
    ),
  );
}

/** 正規の表現で特別な意味を持つ文字を逃がします。 */
function escaped(word: string): string {
  return word.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** 時刻だけを出します。**モックの大きな時刻に当たります。** */
function spellTime(value: string): string {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new MissingResetAtError(`日時として読めません: ${value}`); // 開発者向け
  }
  return new Intl.DateTimeFormat("ja-JP", {
    timeZone: "Asia/Tokyo",
    hour: "2-digit",
    minute: "2-digit",
  }).format(parsed);
}

/**
 * 消費が帰属するクォータ日を出します。
 *
 * **次回のリセット時刻の前日です**（requirements.md 4.4）。境界は日本時間の
 * 3:00 ですので、リセットの時刻から 1 日戻した日が、その消費の帰属です。
 */
export function spellQuotaDay(resetAt: string): string {
  const parsed = new Date(resetAt);
  if (Number.isNaN(parsed.getTime())) {
    throw new MissingResetAtError(`日時として読めません: ${resetAt}`); // 開発者向け
  }
  const previous = new Date(parsed.getTime() - 24 * 60 * 60 * 1000);

  return new Intl.DateTimeFormat("ja-JP", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(previous);
}

/**
 * 失敗の応答から、差し戻しの理由を取り出します。
 *
 * **形が違えば、何も返しません。** 推し量って埋めません。
 */
export function reasonsOf(error: ApiError): ForbiddenReason[] {
  const value = error.details.reasons;
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter(isReason);
}

/**
 * 失敗の応答から、次回のリセット時刻を取り出します。
 *
 * **無ければ、その場で失敗させます**（PR #174 のレビュー・提案 22）。
 * 契約は `quota_exhausted` に `details.reset_at` を必ず添えます。
 * **既定へ寄せると、時刻を出さない上限到達の画面が黙って出ます。**
 */
export function resetAtOf(error: ApiError): string {
  const value = error.details.reset_at;
  if (typeof value !== "string") {
    throw new MissingResetAtError("上限到達に次回のリセット時刻がありません。"); // 開発者向け
  }
  return value;
}

/**
 * 使い切った枠の状態を取り出します（`details.status`、issue #183）。
 *
 * **形が違えば、何も返しません。** `confirmed` 以外の値のときは、画面側が
 * 「状態」の行を出しません。
 */
export function quotaStatusOf(error: ApiError): string | undefined {
  const value = error.details.status;
  return typeof value === "string" ? value : undefined;
}

/**
 * 本日確定した生成リクエストの識別子を取り出します
 * （`details.result_prompt_request_id`、issue #183）。
 *
 * **確定（`confirmed`）のときだけ添えられます。** 予約中（`reserved`）は、
 * まだ見せられる結果がありません。**形が違えば、何も返しません。**
 */
export function resultRequestIdOf(error: ApiError): number | undefined {
  const value = error.details.result_prompt_request_id;
  return typeof value === "number" ? value : undefined;
}

function isReason(value: unknown): value is ForbiddenReason {
  if (typeof value !== "object" || value === null) {
    return false;
  }
  const item = value as Record<string, unknown>;
  return (
    typeof item.kind === "string" &&
    typeof item.matched === "string" &&
    typeof item.suggestion_key === "string"
  );
}
