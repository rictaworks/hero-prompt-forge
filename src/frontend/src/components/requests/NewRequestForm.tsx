"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import type { FormEvent, ReactNode } from "react";
import { Button, SectionHeading } from "@/components/ui";
import { ErrorNotice, UnexpectedErrorNotice } from "@/components/feedback";
import {
  QuotaPanel,
  RejectionPanel,
  reasonsOf,
  resetAtOf,
} from "@/components/exceptions";
import { RECAPTCHA_TOKEN_HEADER } from "@/config/recaptcha";
import { apiGet, apiPost } from "@/lib/api";
import { spellChoice } from "@/lib/format";
import { humanToken } from "@/lib/recaptcha";
import { text } from "@/strings";
import { ApiError } from "@/types/api";
import {
  ASPECT_RATIOS,
  BRAND_COLOR_FORMAT,
  BRAND_TONES,
  COPY_SPACE_POSITIONS,
  DEFAULT_ASPECT_RATIO,
  DEFAULT_COPY_SPACE_POSITION,
  INDUSTRIES,
  MAX_SERVICE_SUMMARY_LENGTH,
  STYLE_FAMILIES,
  TARGET_MODELS,
  MAX_PRESET_NAME_LENGTH,
  type Preset,
  type Project,
  type ProjectList,
  type PromptInputs,
  type PromptRequestSummary,
} from "@/types/resources";
import styles from "./new-request.module.css";

/** 新しく作ることを表す値です。 */
const NEW_PROJECT = "";

/** 名前の書き方の例です（issue #152）。**3 つ以上示します。** */
const NAMING_EXAMPLES = ["quoted", "reading", "company"] as const;

export interface FormState {
  projectId: string;
  projectName: string;
  industry: string;
  styleFamily: string;
  targetModel: string;
  brandTone: string;
  serviceSummary: string;
  brandColorFirst: string;
  brandColorSecond: string;
  copySpacePosition: string;
  aspectRatio: string;
}

export const EMPTY_FORM: FormState = {
  projectId: NEW_PROJECT,
  projectName: "",
  industry: "",
  styleFamily: "",
  targetModel: "",
  brandTone: "",
  serviceSummary: "",
  brandColorFirst: "",
  brandColorSecond: "",
  copySpacePosition: DEFAULT_COPY_SPACE_POSITION,
  aspectRatio: DEFAULT_ASPECT_RATIO,
};

/** 項目ごとの誤りです。**画面で止めます。** */
export type FieldErrors = Partial<Record<keyof FormState, string>>;

/**
 * 入力フォーム（03）です（issue #71、#152）。
 *
 * **必須の 3 項目を、画面で止めます。** 送ってから断られるのではなく、
 * 送る前にどこを直せばよいかをお伝えします。
 *
 * **ネイティブの警告表示（alert 等）を使いません**（CLAUDE.md）。
 *
 * **禁止入力の差し戻しを、この画面に出します。** 見つかった語と直し方を
 * そのままお見せします。**枠は使っていません。**
 *
 * **お名前の書き方を案内します**（issue #152）。案内が無いと、名前が
 * 反映されないまま生成され、出来上がった絵を見て初めて気づきます。
 */
export function NewRequestForm() {
  const router = useRouter();
  const params = useSearchParams();
  const { projects, loading, loadError } = useProjects();
  // **手で直した内容です。** 触るまでは空です。
  const [edited, setEdited] = useState<FormState | null>(null);
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  const [submitError, setSubmitError] = useState<unknown>(null);
  const [submitting, setSubmitting] = useState(false);

  // 履歴の「同じ条件で作る」から来た場合に、そのプロジェクトを選んでおきます。
  //
  // **状態を書き戻しません。** 一覧が届いたときの初期値は、そのつど
  // 組み立てて求めます。効き目のあとで状態を書き戻すと、描き直しが重なります。
  const requested = params.get("project_id");
  const presetId = params.get("preset_id");
  const { preset, presetError } = usePreset(presetId);
  const initial = useMemo(
    () => initialForm(projects, requested, preset),
    [projects, requested, preset],
  );
  const form = edited ?? initial;

  const update = (field: keyof FormState, value: string): void => {
    setEdited({ ...form, [field]: value });
  };

  const submit = async (event: FormEvent<HTMLFormElement>): Promise<void> => {
    event.preventDefault();
    setSubmitError(null);

    const found = validate(form);
    setFieldErrors(found);
    if (Object.keys(found).length > 0) {
      return;
    }

    setSubmitting(true);
    try {
      const created = await accept(form);
      router.push(`/requests/${created.id}`);
    } catch (cause) {
      setSubmitError(cause);
      setSubmitting(false);
    }
  };

  const failure = loadError ?? presetError;
  if (failure) {
    return failure instanceof ApiError ? (
      <ErrorNotice error={failure} />
    ) : (
      <UnexpectedErrorNotice />
    );
  }

  return (
    <div className={styles.section}>
      <SectionHeading
        eyebrow={text("newRequest.labels.eyebrow")}
        title={text("newRequest.labels.title")}
      >
        {text("newRequest.body")}
      </SectionHeading>

      <SubmitFeedback error={submitError} />

      <form className={styles.form} onSubmit={submit} noValidate>
        <fieldset className={styles.group}>
          <legend className={styles.legend}>
            {text("newRequest.labels.projectHeading")}
          </legend>
          <p className={styles.help}>{text("newRequest.projectHelp")}</p>

          <Field id="project" label={text("newRequest.labels.project")}>
            <select
              id="project"
              className={styles.control}
              value={form.projectId}
              disabled={loading}
              onChange={(event) => update("projectId", event.target.value)}
            >
              <option value={NEW_PROJECT}>{text("newRequest.labels.projectNew")}</option>
              {projects.map((project) => (
                <option key={project.id} value={String(project.id)}>
                  {nameOf(project)}
                </option>
              ))}
            </select>
          </Field>

          {form.projectId === NEW_PROJECT ? (
            <Field id="project-name" label={text("newRequest.labels.projectName")}>
              <input
                id="project-name"
                type="text"
                className={styles.control}
                maxLength={100}
                value={form.projectName}
                onChange={(event) => update("projectName", event.target.value)}
              />
            </Field>
          ) : null}
        </fieldset>

        <fieldset className={styles.group}>
          <legend className={styles.legend}>
            {text("newRequest.labels.requiredHeading")}
          </legend>

          <ChoiceField
            id="industry"
            label={text("newRequest.labels.industry")}
            group="industry"
            options={INDUSTRIES}
            value={form.industry}
            required
            error={fieldErrors.industry}
            onChange={(value) => update("industry", value)}
          />
          <ChoiceField
            id="style-family"
            label={text("newRequest.labels.styleFamily")}
            group="styleFamily"
            options={STYLE_FAMILIES}
            value={form.styleFamily}
            required
            error={fieldErrors.styleFamily}
            onChange={(value) => update("styleFamily", value)}
          />
          <ChoiceField
            id="target-model"
            label={text("newRequest.labels.targetModel")}
            group="targetModel"
            options={TARGET_MODELS}
            value={form.targetModel}
            required
            error={fieldErrors.targetModel}
            onChange={(value) => update("targetModel", value)}
          />
        </fieldset>

        <fieldset className={styles.group}>
          <legend className={styles.legend}>
            {text("newRequest.labels.optionalHeading")}
          </legend>

          <ChoiceField
            id="brand-tone"
            label={text("newRequest.labels.brandTone")}
            group="brandTone"
            options={BRAND_TONES}
            value={form.brandTone}
            placeholder={text("newRequest.labels.unspecified")}
            onChange={(value) => update("brandTone", value)}
          />

          <NamingGuide />

          <Field
            id="service-summary"
            label={text("newRequest.labels.serviceSummary")}
            help={text("newRequest.serviceSummaryHelp")}
            error={fieldErrors.serviceSummary}
          >
            <textarea
              id="service-summary"
              className={`${styles.control} ${styles.textarea}`}
              rows={6}
              value={form.serviceSummary}
              onChange={(event) => update("serviceSummary", event.target.value)}
            />
            <p className={styles.counter}>
              {`${form.serviceSummary.length} / ${MAX_SERVICE_SUMMARY_LENGTH}${text("newRequest.labels.counterUnit")}`}
            </p>
          </Field>

          <Field
            id="brand-color-first"
            label={text("newRequest.labels.brandColors")}
            help={text("newRequest.brandColorsHelp")}
            error={fieldErrors.brandColorFirst ?? fieldErrors.brandColorSecond}
          >
            <div className={styles.colors}>
              <label className={styles.colorLabel} htmlFor="brand-color-first">
                {text("newRequest.labels.brandColorFirst")}
              </label>
              <input
                id="brand-color-first"
                type="text"
                className={styles.control}
                placeholder="#000000"
                value={form.brandColorFirst}
                onChange={(event) => update("brandColorFirst", event.target.value)}
              />
              <label className={styles.colorLabel} htmlFor="brand-color-second">
                {text("newRequest.labels.brandColorSecond")}
              </label>
              <input
                id="brand-color-second"
                type="text"
                className={styles.control}
                placeholder="#000000"
                value={form.brandColorSecond}
                onChange={(event) => update("brandColorSecond", event.target.value)}
              />
            </div>
          </Field>

          <ChoiceField
            id="copy-space-position"
            label={text("newRequest.labels.copySpacePosition")}
            group="copySpacePosition"
            options={COPY_SPACE_POSITIONS}
            value={form.copySpacePosition}
            onChange={(value) => update("copySpacePosition", value)}
          />
          <ChoiceField
            id="aspect-ratio"
            label={text("newRequest.labels.aspectRatio")}
            group="aspectRatio"
            options={ASPECT_RATIOS}
            value={form.aspectRatio}
            onChange={(value) => update("aspectRatio", value)}
          />
        </fieldset>

        <SavePreset form={form} />

        <div className={styles.submit}>
          <Button variant="submit" disabled={submitting} fullWidth>
            {submitting
              ? text("newRequest.labels.submitting")
              : text("newRequest.labels.submit")}
          </Button>
        </div>
      </form>
    </div>
  );
}

/** 送ったあとの伝え方です。**種類ごとに見せ方を変えます。** */
function SubmitFeedback({ error }: { error: unknown }) {
  if (error === null) {
    return null;
  }
  if (!(error instanceof ApiError)) {
    return <UnexpectedErrorNotice />;
  }
  if (error.code === "quota_exhausted") {
    return (
      <QuotaPanel
        message={error.message}
        nextAction={error.nextAction}
        resetAt={resetAtOf(error)}
      />
    );
  }
  if (error.code === "forbidden_input") {
    return (
      <RejectionPanel
        message={error.message}
        nextAction={error.nextAction}
        reasons={reasonsOf(error)}
      />
    );
  }
  return <ErrorNotice error={error} />;
}

/**
 * 名前を確実に反映させる書き方の案内です（issue #152）。
 *
 * **利用者は、この決まりを知りません。** 案内が無いと、名前が反映されない
 * まま生成され、出来上がった絵を見て初めて気づきます。
 */
function NamingGuide() {
  return (
    <div className={styles.guide}>
      <div className={styles.guideHeading}>
        {text("newRequest.labels.namingHeading")}
      </div>
      <p className={styles.guideBody}>{text("newRequest.naming.body")}</p>
      <ul className={styles.guideList}>
        {NAMING_EXAMPLES.map((key) => (
          <li key={key} className={styles.guideItem}>
            {text(`newRequest.naming.examples.${key}`)}
          </li>
        ))}
      </ul>
      <p className={styles.guideCaution}>{text("newRequest.naming.caution")}</p>
    </div>
  );
}

interface FieldProps {
  id: string;
  label: string;
  help?: string;
  error?: string;
  required?: boolean;
  children: ReactNode;
}

function Field({ id, label, help, error, required = false, children }: FieldProps) {
  return (
    <div className={styles.field}>
      <label className={styles.label} htmlFor={id}>
        {label}
        {required ? (
          <span className={styles.required}>{text("newRequest.labels.requiredMark")}</span>
        ) : null}
      </label>
      {help ? <p className={styles.help}>{help}</p> : null}
      {children}
      {error ? (
        <p className={styles.error} role="alert">
          {error}
        </p>
      ) : null}
    </div>
  );
}

interface ChoiceFieldProps {
  id: string;
  label: string;
  group: string;
  options: readonly string[];
  value: string;
  required?: boolean;
  placeholder?: string;
  error?: string;
  onChange: (value: string) => void;
}

function ChoiceField({
  id,
  label,
  group,
  options,
  value,
  required = false,
  placeholder,
  error,
  onChange,
}: ChoiceFieldProps) {
  const empty = placeholder ?? text("newRequest.labels.unselected");

  return (
    <Field id={id} label={label} required={required} error={error}>
      <select
        id={id}
        className={styles.control}
        value={value}
        aria-invalid={error ? true : undefined}
        onChange={(event) => onChange(event.target.value)}
      >
        {value === "" || !required ? <option value="">{empty}</option> : null}
        {options.map((option) => (
          <option key={option} value={option}>
            {spellChoice(group, option)}
          </option>
        ))}
      </select>
    </Field>
  );
}

/** プロジェクトの表示名です。**名前が無ければ業種で表します。** */
function nameOf(project: Project): string {
  return project.name ?? spellChoice("industry", project.industry);
}

/**
 * 画面を開いたときの初期値です。
 *
 * **プリセットを先に当て、プロジェクトの指定であとから上書きします。**
 * プロジェクトは保存先そのものですので、そちらを優先します。
 *
 * **見つからない識別子は、無かったものとして扱います。** 他人のものは
 * 一覧に載りませんので、ここで選ばれることもありません。
 */
export function initialForm(
  projects: Project[],
  requested: string | null,
  preset: Preset | null,
): FormState {
  const withPreset = preset === null ? EMPTY_FORM : appliedPreset(preset);
  if (requested === null) {
    return withPreset;
  }
  const found = projects.find((project) => String(project.id) === requested);
  if (!found) {
    return withPreset;
  }
  return {
    ...withPreset,
    projectId: requested,
    industry: found.industry,
    styleFamily: found.style_family,
  };
}

/**
 * プリセットの条件を、入力の形へ写します。
 *
 * **契約に無い項目は取り込みません。** 保存できる項目は
 * `Preset::ALLOWED_CONDITION_KEYS` に閉じています（`SPEC/api/README.md`）。
 * **文字列でない値も取り込みません。** 推し量って直しません。
 */
export function appliedPreset(preset: Preset): FormState {
  const conditions = preset.input_conditions;
  const colors = conditions.brand_colors;
  const listed = Array.isArray(colors) ? colors.filter((color) => typeof color === "string") : [];

  return {
    ...EMPTY_FORM,
    industry: spelled(conditions.industry),
    styleFamily: spelled(conditions.style_family),
    targetModel: spelled(conditions.target_model),
    brandTone: spelled(conditions.brand_tone),
    serviceSummary: spelled(conditions.service_summary),
    brandColorFirst: listed[0] ?? "",
    brandColorSecond: listed[1] ?? "",
    copySpacePosition: spelled(conditions.copy_space_position) || DEFAULT_COPY_SPACE_POSITION,
    aspectRatio: spelled(conditions.aspect_ratio) || DEFAULT_ASPECT_RATIO,
  };
}

function spelled(value: unknown): string {
  return typeof value === "string" ? value : "";
}

/**
 * いまの条件を、名前を付けて保存します（issue #75）。
 *
 * **入力条件を入れた場所で保存できます。** 別の画面へ移って入れ直すより、
 * 手数が少なくなります。
 */
function SavePreset({ form }: { form: FormState }) {
  const [name, setName] = useState("");
  const [saved, setSaved] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<unknown>(null);

  const save = (): void => {
    if (name === "") {
      setError(null);
      setSaved(false);
      return;
    }

    setSaving(true);
    setError(null);

    apiPost<Preset>("/presets", {
      body: { preset: { name: name, input_conditions: inputsOf(form) } },
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

  return (
    <fieldset className={styles.group}>
      <legend className={styles.legend}>{text("presets.labels.newHeading")}</legend>

      {error instanceof ApiError ? <ErrorNotice error={error} /> : null}
      {error !== null && !(error instanceof ApiError) ? <UnexpectedErrorNotice /> : null}

      <Field
        id="preset-name"
        label={text("presets.labels.nameHeading")}
        error={name === "" ? undefined : undefined}
      >
        <input
          id="preset-name"
          type="text"
          className={styles.control}
          maxLength={MAX_PRESET_NAME_LENGTH}
          value={name}
          onChange={(event) => {
            setName(event.target.value);
            setSaved(false);
          }}
        />
      </Field>

      {saved ? <p className={styles.saved}>{text("presets.savedNotice")}</p> : null}
      {name === "" ? <p className={styles.help}>{text("presets.nameRequired")}</p> : null}

      <div className={styles.presetSubmit}>
        <Button
          variant="outline"
          icon={saved ? "check" : "floppy-disk"}
          iconPosition="start"
          disabled={saving || name === ""}
          onClick={save}
        >
          {saving
            ? text("presets.labels.saving")
            : saved
              ? text("presets.labels.saved")
              : text("presets.labels.save")}
        </Button>
      </div>
    </fieldset>
  );
}

/**
 * 呼び出すプリセットを引きます。
 *
 * **指定が無ければ、何も引きません。** 画面を移るたびに問い合わせません。
 */
function usePreset(id: string | null): { preset: Preset | null; presetError: unknown } {
  const [preset, setPreset] = useState<Preset | null>(null);
  const [presetError, setPresetError] = useState<unknown>(null);

  useEffect(() => {
    if (id === null) {
      return;
    }
    const controller = new AbortController();

    apiGet<Preset>(`/presets/${id}`, { signal: controller.signal })
      .then(setPreset)
      .catch((cause) => {
        if (controller.signal.aborted) {
          return;
        }
        setPresetError(cause);
      });

    return () => controller.abort();
  }, [id]);

  return { preset, presetError };
}

/**
 * 画面で止める検査です。
 *
 * **必須の 3 項目**と、**送る前に分かる形の誤り**だけを見ます。
 * 規則による差し戻し（禁止入力）は、送ってからでないと分かりません。
 */
export function validate(form: FormState): FieldErrors {
  const found: FieldErrors = {};

  if (form.industry === "") {
    found.industry = text("newRequest.errors.industryMissing");
  }
  if (form.styleFamily === "") {
    found.styleFamily = text("newRequest.errors.styleFamilyMissing");
  }
  if (form.targetModel === "") {
    found.targetModel = text("newRequest.errors.targetModelMissing");
  }
  if (form.serviceSummary.length > MAX_SERVICE_SUMMARY_LENGTH) {
    found.serviceSummary = text("newRequest.errors.serviceSummaryTooLong");
  }
  if (form.brandColorFirst !== "" && !BRAND_COLOR_FORMAT.test(form.brandColorFirst)) {
    found.brandColorFirst = text("newRequest.errors.brandColorFormat");
  }
  if (form.brandColorSecond !== "" && !BRAND_COLOR_FORMAT.test(form.brandColorSecond)) {
    found.brandColorSecond = text("newRequest.errors.brandColorFormat");
  }

  return found;
}

/** 送る形へ直します。**空の項目は送りません。** */
export function inputsOf(form: FormState): PromptInputs {
  const colors = [form.brandColorFirst, form.brandColorSecond].filter(
    (color) => color !== "",
  );

  const inputs: PromptInputs = {
    industry: form.industry,
    style_family: form.styleFamily,
    target_model: form.targetModel,
    copy_space_position: form.copySpacePosition,
    aspect_ratio: form.aspectRatio,
  };

  if (form.brandTone !== "") {
    inputs.brand_tone = form.brandTone;
  }
  if (form.serviceSummary !== "") {
    inputs.service_summary = form.serviceSummary;
  }
  if (colors.length > 0) {
    inputs.brand_colors = colors;
  }

  return inputs;
}

/**
 * プロジェクトを決めて、生成リクエストを投入します。
 *
 * **プロジェクトを選んでいない場合は、先に作ります。** 生成リクエストは
 * 必ずプロジェクトに属します。
 *
 * **人の操作の合図を、見出しで送ります。** 本文へ混ぜません。
 */
async function accept(form: FormState): Promise<PromptRequestSummary> {
  const token = await humanToken();
  const projectId =
    form.projectId === NEW_PROJECT ? await createProject(form) : Number(form.projectId);

  return apiPost<PromptRequestSummary>("/prompt_requests", {
    body: { project_id: projectId, inputs: inputsOf(form) },
    headers: token === null ? {} : { [RECAPTCHA_TOKEN_HEADER]: token },
  });
}

async function createProject(form: FormState): Promise<number> {
  const created = await apiPost<Project>("/projects", {
    body: {
      project: {
        name: form.projectName === "" ? null : form.projectName,
        industry: form.industry,
        style_family: form.styleFamily,
      },
    },
  });
  return created.id;
}

interface Projects {
  projects: Project[];
  loading: boolean;
  loadError: unknown;
}

/** プロジェクトの一覧を引きます。**失敗を握りつぶしません。** */
function useProjects(): Projects {
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<unknown>(null);

  useEffect(() => {
    const controller = new AbortController();

    apiGet<ProjectList>("/projects", { signal: controller.signal })
      .then((list) => {
        setProjects(list.projects);
        setLoading(false);
      })
      .catch((cause) => {
        if (controller.signal.aborted) {
          return;
        }
        setLoadError(cause);
        setLoading(false);
      });

    return () => controller.abort();
  }, []);

  return { projects, loading, loadError };
}
