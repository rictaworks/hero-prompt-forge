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
  variation_no: number;
  composition_type: string;
  main_prompt: string;
  negative_prompt: string | null;
  parameters: Record<string, unknown>;
  art_direction_note: Record<string, unknown>;
  degraded: boolean;
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
  outputs?: PromptOutput[];
  failure?: RequestFailure;
}
