"use client";

import Link from "next/link";
import { Banner } from "@/components/feedback";
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

export interface QuotaPanelProps {
  /** 利用者に見せる文言です。 */
  message: string;
  /** 次に行う操作です。**次回のリセット時刻を含みます。** */
  nextAction: string;
  /** 次回のリセット時刻です。**契約が `details.reset_at` に添えます。** */
  resetAt: string | null;
}

/**
 * 上限到達です（requirements.md 4.4）。
 *
 * **次回のリセット時刻を必ず出します。** 曖昧なエラーを返しません。
 */
export function QuotaPanel({ message, nextAction, resetAt }: QuotaPanelProps) {
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
          <div className={styles.resetTime}>
            {resetAt === null ? nextAction : spellDateTime(resetAt)}
          </div>
          <div className={styles.resetRule} />
        </div>
        <div className={styles.facts}>
          <p className={styles.factsNote}>{text("exceptions.quotaNote")}</p>
          <div className={styles.actions}>
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
}

/**
 * 禁止入力による差し戻しです（requirements.md 4.1 の 1）。
 *
 * **枠を使っていないことは、API の文言が伝えます。**
 *
 * **見つかった語は、要求した本人が送った入力の写しです**（`SPEC/api/README.md`）。
 * **React が逃がしますので、そのまま描いて差し支えありません。**
 */
export function RejectionPanel({ message, nextAction, reasons }: RejectionPanelProps) {
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
        </div>
      ) : null}
    </section>
  );
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

/** 失敗の応答から、次回のリセット時刻を取り出します。**無ければ空です。** */
export function resetAtOf(error: ApiError): string | null {
  const value = error.details.reset_at;
  return typeof value === "string" ? value : null;
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
