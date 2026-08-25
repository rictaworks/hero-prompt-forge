/**
 * フロントエンドとバックエンドが共通で守る型です。
 *
 * 決まりは SPEC/api/README.md にあります。ここは、その決まりを型で表したものです。
 * 実装していないエンドポイントの型を先に書きません。
 */

/** 失敗の応答です。すべての失敗でこの形を返します。 */
export interface ApiErrorBody {
  /** 機械が判定するための識別子です。 */
  code: string;
  /** 利用者に見せる文言です。 */
  message: string;
  /** 次に行う操作です。空にしません。 */
  next_action: string;
  /** 補足です。個人情報・秘匿値を入れません。 */
  details?: Record<string, unknown>;
}

export interface ApiErrorResponse {
  error: ApiErrorBody;
}

/** 応答が失敗の形かどうかを判定します。 */
export function isApiErrorResponse(value: unknown): value is ApiErrorResponse {
  if (typeof value !== "object" || value === null || !("error" in value)) {
    return false;
  }
  const error = (value as { error: unknown }).error;
  if (typeof error !== "object" || error === null) {
    return false;
  }
  const body = error as Record<string, unknown>;
  return (
    typeof body.code === "string" &&
    typeof body.message === "string" &&
    typeof body.next_action === "string"
  );
}

/** API が失敗を返したことを表す例外です。握りつぶさず、この形で投げ直します。 */
export class ApiError extends Error {
  readonly code: string;
  readonly nextAction: string;
  readonly status: number;
  readonly details: Record<string, unknown>;

  constructor(status: number, body: ApiErrorBody) {
    super(body.message);
    this.name = "ApiError";
    this.status = status;
    this.code = body.code;
    this.nextAction = body.next_action;
    this.details = body.details ?? {};
  }
}

/** JST の ISO 8601 文字列です。 */
export type JstDateTime = string;
