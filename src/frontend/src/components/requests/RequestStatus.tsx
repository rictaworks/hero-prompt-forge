"use client";

import Link from "next/link";
import { Banner, ErrorNotice, UnexpectedErrorNotice } from "@/components/feedback";
import { RejectionPanel } from "@/components/exceptions";
import { Button, SectionHeading } from "@/components/ui";
import { spellChoice, spellDateTime } from "@/lib/format";
import { useRequest } from "@/hooks/useRequest";
import { text } from "@/strings";
import { ApiError } from "@/types/api";
import type { PromptRequestDetail } from "@/types/resources";
import styles from "./request-status.module.css";

/**
 * 生成中（04）と、縮退・失敗・差し戻し（08）です（issue #72、#76）。
 *
 * **状態が進むと表示が切り替わります。** 決着するまで、状態を取りに行き続けます。
 *
 * **曖昧なエラーを出しません。** 失敗した場合は、API が返した文言と、
 * 次に行う操作をそのまま出します。
 *
 * **縮退で作られた案には印を出します**（requirements.md 4.2）。
 */
export function RequestStatus({ id }: { id: string }) {
  const { request, error } = useRequest(id);

  if (error) {
    return error instanceof ApiError ? (
      <ErrorNotice error={error} />
    ) : (
      <UnexpectedErrorNotice />
    );
  }

  if (request === null) {
    return <p className={styles.loading}>{text("requestStatus.loading")}</p>;
  }

  return (
    <div className={styles.section}>
      <SectionHeading
        eyebrow={text("requestStatus.labels.eyebrow")}
        title={text("requestStatus.labels.title")}
      />

      <StateBanner request={request} />
      <Facts request={request} />
      <Actions request={request} />
    </div>
  );
}

/** 状態ごとの伝え方です。**どの状態でも、必ず何かをお伝えします。** */
function StateBanner({ request }: { request: PromptRequestDetail }) {
  switch (request.status) {
    case "draft":
    case "queued":
      return (
        <Banner kind="notice" title={spellChoice("status", request.status)}>
          {text("requestStatus.queued")}
        </Banner>
      );
    case "generating":
      return (
        <Banner kind="notice" title={spellChoice("status", request.status)}>
          {text("requestStatus.generating")}
        </Banner>
      );
    case "completed":
      return (
        <Banner
          kind="notice"
          title={text("requestStatus.labels.completedEyebrow")}
        >
          {text("requestStatus.completed")}
        </Banner>
      );
    case "degraded_completed":
      return <DegradedPanel />;
    case "rejected":
      return <RejectionBanner request={request} />;
    case "failed":
      return <FailureBanner request={request} />;
    case "archived":
      return (
        <Banner kind="notice" title={spellChoice("status", request.status)}>
          {text("requestStatus.archived")}
        </Banner>
      );
    default:
      return <UnexpectedErrorNotice />;
  }
}

/**
 * 縮退での完了です（requirements.md 5.1）。
 *
 * 体裁は `app-ui/degraded.html` の「縮退モード」に合わせます。
 */
function DegradedPanel() {
  return (
    <div>
      <Banner kind="degraded" title={text("requestStatus.labels.degradedEyebrow")}>
        {text("requestStatus.degraded")}
      </Banner>
      <div className={styles.panel}>
        <div className={styles.chips}>
          <span className={`${styles.chip} ${styles.chipWarn}`}>
            {text("requestStatus.labels.degradedChip")}
          </span>
        </div>
        <p className={styles.note}>{text("requestStatus.degradedNote")}</p>
      </div>
    </div>
  );
}

/**
 * 禁止入力による差し戻しです。**文言は API が返します。**
 *
 * **見つかった語は、取り出しの経路では返りません**（`SPEC/api/README.md`）。
 * 受け付けたその場でお返しした内容にだけ含まれます。**推し量って補いません。**
 */
function RejectionBanner({ request }: { request: PromptRequestDetail }) {
  const failure = request.failure;
  if (!failure) {
    return <UnexpectedErrorNotice />;
  }

  return (
    <RejectionPanel
      message={failure.message}
      nextAction={failure.next_action}
      reasons={[]}
    />
  );
}

/** 生成の失敗です。**枠を返していることは、API の文言が伝えます。** */
function FailureBanner({ request }: { request: PromptRequestDetail }) {
  const failure = request.failure;
  if (!failure) {
    return <UnexpectedErrorNotice />;
  }

  return (
    <Banner
      kind="rejected"
      title={text("requestStatus.labels.failedEyebrow")}
      nextAction={failure.next_action}
    >
      {failure.message}
    </Banner>
  );
}

/** 生成リクエストの素性です。 */
function Facts({ request }: { request: PromptRequestDetail }) {
  const rows = [
    { key: "stateHeading", value: spellChoice("status", request.status) },
    { key: "modelHeading", value: spellChoice("targetModel", request.target_model) },
    { key: "startedHeading", value: spellDateTime(request.created_at) },
  ];

  return (
    <div className={styles.panel}>
      <div className={styles.facts}>
        {rows.map((row) => (
          <div key={row.key} className={styles.factsRow}>
            <span className={styles.factsKey}>
              {text(`requestStatus.labels.${row.key}`)}
            </span>
            <span className={styles.factsValue}>{row.value}</span>
          </div>
        ))}
        {request.dictionary_version ? (
          <div className={styles.factsRow}>
            <span className={styles.factsKey}>
              {text("requestStatus.labels.dictionaryHeading")}
            </span>
            <span className={styles.factsValue}>{request.dictionary_version}</span>
          </div>
        ) : null}
      </div>
    </div>
  );
}

/**
 * 次に行える操作です。
 *
 * **失敗したときは、作り直す導線を出します**（issue #72）。枠は返っていますので、
 * 当日中に作り直していただけます。
 */
function Actions({ request }: { request: PromptRequestDetail }) {
  const delivered = request.status === "completed" || request.status === "degraded_completed";
  const retryable = request.status === "failed" || request.status === "rejected";

  return (
    <div className={styles.actions}>
      {delivered ? (
        <Button
          variant="outline"
          icon="chevron-right"
          href={`/requests/${request.id}/result`}
        >
          {text("requestStatus.labels.openResult")}
        </Button>
      ) : null}

      {retryable ? (
        <Button
          variant="outline"
          icon="rotate-right"
          iconPosition="start"
          href={`/requests/new?project_id=${request.project_id}`}
        >
          {text("requestStatus.labels.retry")}
        </Button>
      ) : null}

      <Link className={styles.actionLink} href="/projects">
        {text("requestStatus.labels.historyLink")}
      </Link>
    </div>
  );
}
