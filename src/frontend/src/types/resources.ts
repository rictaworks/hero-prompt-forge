/**
 * バックエンドが返す資源の型です。
 *
 * 決まりは `SPEC/api/README.md` にあります。**実装していないエンドポイントの
 * 型を先に書きません。**
 */
import type { JstDateTime } from "@/types/api";

/** 生成リクエストの状態です（requirements.md 12.1）。 */
export const REQUEST_STATUSES = [
  "draft",
  "queued",
  "generating",
  "completed",
  "degraded_completed",
  "failed",
  "rejected",
  "archived",
] as const;

export type RequestStatus = (typeof REQUEST_STATUSES)[number];

/** 成果物を提供した状態です。 */
export const DELIVERED_STATUSES: readonly RequestStatus[] = [
  "completed",
  "degraded_completed",
];

/** まだ動いている状態です。**結果を取りに来続けます。** */
export const PENDING_STATUSES: readonly RequestStatus[] = [
  "draft",
  "queued",
  "generating",
];

export interface Project {
  id: number;
  name: string | null;
  industry: string;
  style_family: string;
  brand_settings: Record<string, unknown>;
  created_at: JstDateTime;
  updated_at: JstDateTime;
}

export interface ProjectList {
  projects: Project[];
}

/** 生成リクエストの、一覧に載る形です。 */
export interface PromptRequestSummary {
  id: number;
  project_id: number;
  status: RequestStatus;
  degraded: boolean;
  target_model: string;
  dictionary_version: string | null;
  created_at: JstDateTime;
  updated_at: JstDateTime;
  outputs_count: number;
}

export interface PromptRequestList {
  prompt_requests: PromptRequestSummary[];
}

/** 1 案ぶんの出力です。 */
export interface PromptOutput {
  /** 案の識別子です。**評価メモの記録に使います。** */
  id: number;
  variation_no: number;
  composition_type: string;
  main_prompt: string;
  negative_prompt: string | null;
  parameters: Record<string, unknown>;
  art_direction_note: Record<string, unknown>;
  degraded: boolean;
  /** すでに記録された評価メモです。**無ければ空です。** */
  evaluation_note: EvaluationNote | null;
}

/** 利用者へ理由を添える場合の中身です。 */
export interface RequestFailure {
  code: string;
  message: string;
  next_action: string;
}

/** 生成リクエストの、取り出しの形です。 */
export interface PromptRequestDetail
  extends Omit<PromptRequestSummary, "outputs_count"> {
  /**
   * 正規化済みの入力条件です。
   *
   * **「同じ条件で作り直す」ために使います。** 業種とスタイル系統だけでは、
   * 生成モデル・トーン・サービス概要・ブランドカラー・余白の位置・画角が
   * 失われます（PR #174 のレビューより）。
   *
   * **差し戻した記録には、サービス概要が残っていません。**
   */
  inputs: Record<string, unknown>;
  outputs?: PromptOutput[];
  failure?: RequestFailure;
}

/**
 * 入力条件で選べる値です（`SPEC/api/README.md`）。
 *
 * **API の契約です。** バックエンドの `Generation::InputChoices` と同じ並びを
 * 守ります。**片方だけを増やすと、画面では選べるのに投入で弾かれます。**
 * 契約の正は `SPEC/api/README.md` で、両側がそれを実装します。
 */
export const INDUSTRIES = [
  "saas",
  "restaurant",
  "medical",
  "education",
  "real_estate",
  "manufacturing",
  "professional_services",
  "ecommerce",
  "beauty",
  "other",
] as const;

export const STYLE_FAMILIES = [
  "photoreal",
  "illustration",
  "three_d",
  "abstract",
] as const;

export const TARGET_MODELS = [
  "midjourney",
  "dalle",
  "stable_diffusion",
  "nano_banana",
] as const;

export const BRAND_TONES = [
  "trust",
  "advanced",
  "warmth",
  "premium",
  "friendly",
  "minimal",
] as const;

export const COPY_SPACE_POSITIONS = ["left", "right", "bottom_center"] as const;

export const ASPECT_RATIOS = ["16:9", "21:9", "3:2"] as const;

/** 既定値です。**省いた場合にバックエンドが補う値と同じです。** */
export const DEFAULT_COPY_SPACE_POSITION = "left";
export const DEFAULT_ASPECT_RATIO = "16:9";

/** 上限です。 */
export const MAX_SERVICE_SUMMARY_LENGTH = 1000;
export const MAX_BRAND_COLORS = 2;

/** ブランドカラーの書き方です。 */
export const BRAND_COLOR_FORMAT = /^#[0-9a-fA-F]{6}$/;

/** 生成リクエストへ送る入力条件です。 */
export interface PromptInputs {
  industry: string;
  style_family: string;
  target_model: string;
  brand_tone?: string;
  service_summary?: string;
  brand_colors?: string[];
  copy_space_position?: string;
  aspect_ratio?: string;
}

/** 禁止入力で差し戻されたときの理由です（`SPEC/api/README.md`）。 */
export interface ForbiddenReason {
  kind: string;
  matched: string;
  suggestion_key: string;
}

/** 評価メモです（`SPEC/api/README.md`）。 */
export interface EvaluationNote {
  id: number;
  rating: number | null;
  memo: string | null;
}

/** プリセットです（`SPEC/api/README.md`）。 */
export interface Preset {
  id: number;
  name: string;
  input_conditions: Record<string, unknown>;
  created_at: JstDateTime;
  updated_at: JstDateTime;
}

export interface PresetList {
  presets: Preset[];
}

/** プリセットに保存できる項目です。**契約は `SPEC/api/README.md` です。** */
export const PRESET_CONDITION_KEYS = [
  "industry",
  "style_family",
  "target_model",
  "service_summary",
  "brand_tone",
  "brand_colors",
  "copy_space_position",
  "aspect_ratio",
] as const;

/** プリセットの名前の長さの上限です。 */
export const MAX_PRESET_NAME_LENGTH = 50;

/** プロジェクトの名前（サイト名）の長さの上限です。 */
export const MAX_PROJECT_NAME_LENGTH = 100;

/** 評価の段階です。 */
export const RATINGS = [1, 2, 3, 4, 5] as const;
