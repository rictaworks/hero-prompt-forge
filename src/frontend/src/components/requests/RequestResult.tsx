"use client";

import Link from "next/link";
import { useState } from "react";
import { ErrorNotice, UnexpectedErrorNotice } from "@/components/feedback";
import { Button, SectionHeading } from "@/components/ui";
import { spellChoice } from "@/lib/format";
import { traceError } from "@/lib/logger";
import { useRequest } from "@/hooks/useRequest";
import { text } from "@/strings";
import { ApiError } from "@/types/api";
import type { PromptOutput, PromptRequestDetail } from "@/types/resources";
import styles from "./request-result.module.css";

/**
 * 結果 3 案（05）です（issue #73）。
 *
 * **構図の別とともに 3 案を出します**（requirements.md 4.1 の 8）。
 *
 * **縮退で作られた案には印を出します**（requirements.md 4.2）。案ごとに印が
 * 付きますので、どの案が規則辞書だけで組み立てられたのかが分かります。
 *
 * **アートディレクションノートを添えます**（requirements.md 4.1 の 9）。
 * 見出しはバックエンドが組み立てて返しますので、画面で作り直しません。
 */
export function RequestResult({ id }: { id: string }) {
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

  const outputs = request.outputs ?? [];

  return (
    <div className={styles.section}>
      <SectionHeading
        eyebrow={text("result.labels.eyebrow")}
        title={text("result.labels.title")}
      >
        {text("result.body")}
      </SectionHeading>

      {outputs.length === 0 ? (
        <p className={styles.empty}>{text("result.empty")}</p>
      ) : null}

      {outputs.map((output) => (
        <VariationCard key={output.variation_no} request={request} output={output} />
      ))}

      <div className={styles.actions}>
        <Button
          variant="outline"
          icon="pen-to-square"
          iconPosition="start"
          href={`/requests/${request.id}/notes`}
        >
          {text("result.labels.openNotes")}
        </Button>
        <Link className={styles.actionLink} href={`/requests/${request.id}`}>
          {text("result.labels.backToStatus")}
        </Link>
      </div>
    </div>
  );
}

function VariationCard({
  request,
  output,
}: {
  request: PromptRequestDetail;
  output: PromptOutput;
}) {
  return (
    <article className={styles.card}>
      <header className={styles.head}>
        <div>
          <span className={styles.eyebrow}>
            {`${text("result.labels.variation")} ${String(output.variation_no).padStart(2, "0")}`}
          </span>
          <h3 className={styles.title}>
            {spellChoice("compositionType", output.composition_type)}
          </h3>
          <span className={styles.meta}>
            {spellChoice("targetModel", request.target_model)}
          </span>
        </div>
        <div className={styles.chips}>
          {request.dictionary_version ? (
            <span className={styles.chip}>{request.dictionary_version}</span>
          ) : null}
          {output.degraded ? (
            <span className={`${styles.chip} ${styles.chipWarn}`}>
              {text("result.labels.degradedChip")}
            </span>
          ) : null}
        </div>
      </header>

      <PromptBlock
        heading={text("result.labels.mainPrompt")}
        value={output.main_prompt}
      />

      {output.negative_prompt === null ? (
        <p className={styles.absent}>{text("result.negativeAbsent")}</p>
      ) : (
        <PromptBlock
          heading={text("result.labels.negativePrompt")}
          value={output.negative_prompt}
        />
      )}

      <Parameters parameters={output.parameters} />
      <ArtDirectionNote note={output.art_direction_note} />
    </article>
  );
}

/** 本文と、そのコピーです。 */
function PromptBlock({ heading, value }: { heading: string; value: string }) {
  const { copied, failed, copy } = useCopy(value);

  return (
    <section className={styles.block}>
      <div className={styles.blockHead}>
        <span className={styles.label}>{heading}</span>
        <Button
          variant="outline"
          icon={copied ? "check" : "copy"}
          iconPosition="start"
          onClick={copy}
        >
          {copied ? text("result.labels.copied") : text("result.labels.copy")}
        </Button>
      </div>
      <p className={styles.quote}>{value}</p>
      {failed ? (
        <p className={styles.error} role="alert">
          {text("result.copyFailed")}
        </p>
      ) : null}
    </section>
  );
}

function Parameters({ parameters }: { parameters: Record<string, unknown> }) {
  const entries = Object.entries(parameters);
  if (entries.length === 0) {
    return null;
  }

  return (
    <section className={styles.block}>
      <span className={styles.label}>{text("result.labels.parameters")}</span>
      <div className={styles.facts}>
        {entries.map(([key, value]) => (
          <div key={key} className={styles.factsRow}>
            <span className={styles.factsKey}>{key}</span>
            <span className={styles.factsValue}>{String(value)}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

/** アートディレクションノートの形です（`Generation::ArtDirectionNote`）。 */
interface NoteShape {
  checkpoints?: { key: string; heading: string; text: string }[];
  adjustments?: string[];
  headings?: { checkpoints?: string; adjustments?: string };
}

/**
 * アートディレクションノートです。
 *
 * **見出しはバックエンドが組み立てて返します。** 画面で作り直しません。
 * **形が違えば、何も出しません。** 推し量って埋めません。
 */
function ArtDirectionNote({ note }: { note: Record<string, unknown> }) {
  const shape = note as NoteShape;
  const checkpoints = shape.checkpoints ?? [];
  const adjustments = shape.adjustments ?? [];

  if (checkpoints.length === 0 && adjustments.length === 0) {
    return null;
  }

  return (
    <section className={styles.block}>
      {checkpoints.length > 0 ? (
        <>
          <span className={styles.label}>{shape.headings?.checkpoints}</span>
          <ul className={styles.list}>
            {checkpoints.map((item) => (
              <li key={item.key} className={styles.listItem}>
                <span className={styles.listHeading}>{item.heading}</span>
                {item.text}
              </li>
            ))}
          </ul>
        </>
      ) : null}

      {adjustments.length > 0 ? (
        <>
          <span className={styles.label}>{shape.headings?.adjustments}</span>
          <ul className={styles.list}>
            {adjustments.map((item, index) => (
              <li key={`adjustment-${index}`} className={styles.listItem}>
                {item}
              </li>
            ))}
          </ul>
        </>
      ) : null}
    </section>
  );
}

interface Copy {
  copied: boolean;
  failed: boolean;
  copy: () => void;
}

/**
 * 本文を写し取ります。
 *
 * **失敗を握りつぶしません。** 写し取れなかった場合は、その旨と次に行う
 * 操作を画面でお伝えします。**ネイティブの警告表示を使いません。**
 */
function useCopy(value: string): Copy {
  const [copied, setCopied] = useState(false);
  const [failed, setFailed] = useState(false);

  const copy = (): void => {
    navigator.clipboard
      .writeText(value)
      .then(() => {
        setCopied(true);
        setFailed(false);
      })
      .catch((cause) => {
        traceError("result.copy", cause);
        setCopied(false);
        setFailed(true);
      });
  };

  return { copied, failed, copy };
}
