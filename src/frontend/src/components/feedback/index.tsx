import type { ReactNode } from "react";
import { ApiError } from "@/types/api";
import { text } from "@/strings";
import styles from "./feedback.module.css";

export type BannerKind = "notice" | "degraded" | "rejected";

const ICON: Record<BannerKind, string> = {
  notice: "hourglass-half",
  degraded: "arrow-trend-down",
  rejected: "ban",
};

export interface BannerProps {
  kind: BannerKind;
  title: string;
  children: ReactNode;
  /** 次に行う操作です。省略した場合は表示しません。 */
  nextAction?: string;
}

/**
 * 状態を伝える帯です。app-ui/degraded.html の3種類と同じ体裁です。
 *
 * ネイティブの警告表示（alert 等）を使わず、画面の中で伝えます。
 */
export function Banner({ kind, title, children, nextAction }: BannerProps) {
  return (
    <div className={`${styles.banner} ${styles[kind]}`} role="status">
      <span className={styles.icon}>
        <i className={`fa-solid fa-${ICON[kind]}`} aria-hidden="true" />
      </span>
      <div>
        <div className={styles.title}>{title}</div>
        <p className={styles.text}>{children}</p>
        {nextAction ? <p className={styles.nextAction}>{nextAction}</p> : null}
      </div>
    </div>
  );
}

/** 失敗の種類ごとの見せ方です。 */
const KIND_BY_STATUS: ReadonlyArray<{ status: number; kind: BannerKind }> = [
  { status: 429, kind: "notice" },
  { status: 422, kind: "rejected" },
  { status: 400, kind: "rejected" },
];

function kindOf(status: number): BannerKind {
  return KIND_BY_STATUS.find((entry) => entry.status === status)?.kind ?? "rejected";
}

export interface ErrorNoticeProps {
  error: ApiError;
}

/**
 * API が返した失敗を、そのまま画面へ出します。
 *
 * 契約により、失敗には必ず「何が起きたか」と「次に何をすればよいか」が
 * 含まれます。曖昧な文言へ置き換えず、受け取った内容をそのまま伝えます。
 */
export function ErrorNotice({ error }: ErrorNoticeProps) {
  return (
    <Banner
      kind={kindOf(error.status)}
      title={error.code}
      nextAction={error.nextAction}
    >
      {error.message}
    </Banner>
  );
}

export interface UnexpectedErrorNoticeProps {
  /** 追跡のための識別子です。問い合わせ時に伝えてもらいます。 */
  traceId?: string;
}

/**
 * 想定していない失敗を伝えます。
 *
 * 想定外であっても、次に行う操作を必ず示します。
 */
export function UnexpectedErrorNotice({ traceId }: UnexpectedErrorNoticeProps) {
  return (
    <Banner
      kind="rejected"
      title="UNEXPECTED"
      nextAction={
        traceId
          ? `${text("errors.unexpected.nextAction")}（${text("errors.unexpected.traceLabel")}: ${traceId}）`
          : text("errors.unexpected.nextAction")
      }
    >
      {text("errors.unexpected.message")}
    </Banner>
  );
}
