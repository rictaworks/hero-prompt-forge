"use client";

import { useEffect, useState } from "react";
import { ErrorNotice, UnexpectedErrorNotice } from "@/components/feedback";
import { Button, SectionHeading } from "@/components/ui";
import { apiGet } from "@/lib/api";
import { spellChoice } from "@/lib/format";
import { text } from "@/strings";
import { ApiError } from "@/types/api";
import {
  PRESET_CONDITION_KEYS,
  type Preset,
  type PresetList,
} from "@/types/resources";
import styles from "./presets.module.css";

/**
 * プリセット（07）です（issue #75）。
 *
 * **入力条件の組み合わせを、名前を付けて呼び出せます**（requirements.md 4.3）。
 *
 * **保存は入力フォームで行います。** 条件を入れた場所で、そのまま名前を
 * 付けていただくほうが手数が少なくなります。ここは呼び出しの入口です。
 *
 * **消す経路を作りません。** API が持っていません。
 */
export function Presets() {
  const { presets, loading, error } = usePresets();

  if (error) {
    return error instanceof ApiError ? (
      <ErrorNotice error={error} />
    ) : (
      <UnexpectedErrorNotice />
    );
  }

  return (
    <div className={styles.section}>
      <SectionHeading
        eyebrow={text("presets.labels.eyebrow")}
        title={text("presets.labels.title")}
      >
        {text("presets.body")}
      </SectionHeading>

      <section className={styles.panel} aria-label={text("presets.labels.title")}>
        {loading ? <p className={styles.loading}>{text("presets.loading")}</p> : null}
        {!loading && presets.length === 0 ? (
          <p className={styles.empty}>{text("presets.empty")}</p>
        ) : null}
        {presets.map((preset) => (
          <PresetRow key={preset.id} preset={preset} />
        ))}
      </section>
    </div>
  );
}

function PresetRow({ preset }: { preset: Preset }) {
  return (
    <div className={styles.row}>
      <div className={styles.rowMain}>
        <span className={styles.rowTitle}>{preset.name}</span>
        <span className={styles.rowMeta}>{spelledConditions(preset)}</span>
      </div>
      <div className={styles.actions}>
        <Button
          variant="outline"
          icon="chevron-right"
          href={`/requests/new?preset_id=${preset.id}`}
        >
          {text("presets.labels.use")}
        </Button>
      </div>
    </div>
  );
}

/**
 * 保存されている条件を、読める形にします。
 *
 * **選択肢の値そのものを画面へ出しません。** 呼び名へ直します。
 * **呼び名を持たない項目（自由記述・色）は、値をそのまま出します。**
 */
export function spelledConditions(preset: Preset): string {
  const spelled = PRESET_CONDITION_KEYS.flatMap((key) => {
    const value = preset.input_conditions[key];
    if (value === undefined || value === null || value === "") {
      return [];
    }
    return [spelledValue(key, value)];
  });

  return spelled.join(" / ");
}

/** 呼び名を持つ項目です。**設定から引きます。** */
const SPELLED_GROUPS: Record<string, string> = {
  industry: "industry",
  style_family: "styleFamily",
  target_model: "targetModel",
  brand_tone: "brandTone",
  copy_space_position: "copySpacePosition",
  aspect_ratio: "aspectRatio",
};

function spelledValue(key: string, value: unknown): string {
  const group = SPELLED_GROUPS[key];
  if (group !== undefined && typeof value === "string") {
    return spellChoice(group, value);
  }
  if (Array.isArray(value)) {
    return value.map(String).join(" ");
  }
  return String(value);
}

interface Presets {
  presets: Preset[];
  loading: boolean;
  error: unknown;
}

function usePresets(): Presets {
  const [presets, setPresets] = useState<Preset[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<unknown>(null);

  useEffect(() => {
    const controller = new AbortController();

    apiGet<PresetList>("/presets", { signal: controller.signal })
      .then((list) => {
        setPresets(list.presets);
        setLoading(false);
      })
      .catch((cause) => {
        if (controller.signal.aborted) {
          return;
        }
        setError(cause);
        setLoading(false);
      });

    return () => controller.abort();
  }, []);

  return { presets, loading, error };
}
