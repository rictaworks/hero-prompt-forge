"use client";

import Link from "next/link";
import { useState } from "react";
import { ErrorNotice, UnexpectedErrorNotice } from "@/components/feedback";
import { Button, SectionHeading } from "@/components/ui";
import { apiPost } from "@/lib/api";
import { spellChoice } from "@/lib/format";
import { useRequest } from "@/hooks/useRequest";
import { text } from "@/strings";
import { ApiError } from "@/types/api";
import { RATINGS, type PromptOutput } from "@/types/resources";
import styles from "./request-notes.module.css";

/**
 * 評価メモ（06）です（issue #74）。
 *
 * **生成した絵を実際に作ってみた所感を残します**（requirements.md 4.3）。
 *
 * **上限に達していても記録できます。** 記録は生成ではありませんので、
 * 枠の判定を通りません（`SPEC/api/README.md`）。
 *
 * **案 1 つにつき 1 件です。** すでにある案へ送ると書き換わります。
 */
export function RequestNotes({ id }: { id: string }) {
  const { request, error } = useRequest(id);

  if (error) {
    return error instanceof ApiError ? (
      <ErrorNotice error={error} />
    ) : (
      <UnexpectedErrorNotice />
    );
  }

  if (request === null) {
    return <p className={styles.loading}>{text("evaluation.loading")}</p>;
  }

  const outputs = request.outputs ?? [];

  return (
    <div className={styles.section}>
      <SectionHeading
        eyebrow={text("evaluation.labels.eyebrow")}
        title={text("evaluation.labels.title")}
      >
        {text("evaluation.body")}
      </SectionHeading>

      <p className={styles.note}>{text("evaluation.quotaNote")}</p>

      {outputs.length === 0 ? (
        <p className={styles.empty}>{text("evaluation.empty")}</p>
      ) : null}

      {outputs.map((output) => (
        <NoteForm key={output.id} output={output} />
      ))}

      <div className={styles.actions}>
        <Link className={styles.actionLink} href={`/requests/${request.id}/result`}>
          {text("evaluation.labels.backToResult")}
        </Link>
      </div>
    </div>
  );
}

/** 1 案ぶんの記録です。 */
function NoteForm({ output }: { output: PromptOutput }) {
  const existing = output.evaluation_note;
  const [rating, setRating] = useState<string>(
    existing?.rating === null || existing === null ? "" : String(existing.rating),
  );
  const [memo, setMemo] = useState<string>(existing?.memo ?? "");
  const [saved, setSaved] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<unknown>(null);

  const save = (): void => {
    setSaving(true);
    setError(null);

    apiPost(`/prompt_outputs/${output.id}/evaluation_note`, {
      body: {
        evaluation_note: {
          rating: rating === "" ? null : Number(rating),
          memo: memo === "" ? null : memo,
        },
      },
    })
      .then(() => {
        setSaved(true);
        setSaving(false);
      })
      .catch((cause) => {
        setError(cause);
        setSaving(false);
      });
  };

  const ratingName = `rating-${output.id}`;
  const memoId = `memo-${output.id}`;

  return (
    <article className={styles.card}>
      <header className={styles.head}>
        <span className={styles.eyebrow}>
          {`${text("result.labels.variation")} ${String(output.variation_no).padStart(2, "0")}`}
        </span>
        <h3 className={styles.title}>
          {spellChoice("compositionType", output.composition_type)}
        </h3>
      </header>

      <p className={styles.excerpt}>{output.main_prompt}</p>

      {error ? <Feedback error={error} /> : null}

      <fieldset className={styles.group}>
        <legend className={styles.label}>{text("evaluation.labels.ratingHeading")}</legend>
        <div className={styles.ratings}>
          <label className={styles.rating}>
            <input
              type="radio"
              name={ratingName}
              value=""
              checked={rating === ""}
              onChange={() => setRating("")}
            />
            {text("evaluation.labels.unrated")}
          </label>
          {RATINGS.map((value) => (
            <label key={value} className={styles.rating}>
              <input
                type="radio"
                name={ratingName}
                value={String(value)}
                checked={rating === String(value)}
                onChange={() => setRating(String(value))}
              />
              {value}
            </label>
          ))}
        </div>
      </fieldset>

      <div className={styles.field}>
        <label className={styles.label} htmlFor={memoId}>
          {text("evaluation.labels.memoHeading")}
        </label>
        <textarea
          id={memoId}
          className={styles.control}
          rows={4}
          value={memo}
          onChange={(event) => {
            setMemo(event.target.value);
            setSaved(false);
          }}
        />
      </div>

      <div className={styles.submit}>
        <Button
          variant="outline"
          icon={saved ? "check" : "floppy-disk"}
          iconPosition="start"
          disabled={saving}
          onClick={save}
        >
          {saving
            ? text("evaluation.labels.saving")
            : saved
              ? text("evaluation.labels.saved")
              : text("evaluation.labels.save")}
        </Button>
      </div>
    </article>
  );
}

function Feedback({ error }: { error: unknown }) {
  return error instanceof ApiError ? (
    <ErrorNotice error={error} />
  ) : (
    <UnexpectedErrorNotice />
  );
}
