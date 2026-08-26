import { ApiError, isApiErrorResponse } from "@/types/api";
import { traceError, traceInfo } from "@/lib/logger";

/**
 * バックエンドへの呼び出しです。
 *
 * **画面と同じ場所（`/api/v1/...`）へ送ります。** 実際の呼び出し先は
 * Next.js の書き換えがサーバー側で解決します。**バックエンドの場所を
 * 画面へ書きません**（CLAUDE.md）。
 *
 * **失敗を握りつぶしません。** 契約の形（`code` ・ `message` ・
 * `next_action`）で返ってきた失敗は `ApiError` として投げ直します。
 * **契約の形で返ってこなかった失敗も、そのまま投げます。** 既定の値へ
 * 寄せると、画面は「成功したのに何も出ない」状態になります。
 *
 * **セッションのクッキーを必ず送ります。** 認証はクッキーによります。
 */
export const API_BASE_PATH = "/api/v1";

/** 契約の形で返ってこなかった応答です。 */
export class UnexpectedResponseError extends Error {
  readonly status: number;

  constructor(status: number, message: string) {
    super(message);
    this.name = "UnexpectedResponseError";
    this.status = status;
  }
}

export type Query = Record<string, string | number | undefined>;

export interface RequestOptions {
  /** 問い合わせの文字列です。空の値は送りません。 */
  query?: Query;
  /** 送る本体です。連想配列を JSON にして送ります。 */
  body?: unknown;
  /** 追加の見出しです。合図（reCAPTCHA）などに使います。 */
  headers?: Record<string, string>;
  /** 途中でやめるための合図です。 */
  signal?: AbortSignal;
}

function queryString(query: Query | undefined): string {
  if (!query) {
    return "";
  }
  const entries = Object.entries(query).filter(
    ([, value]) => value !== undefined && value !== "",
  );
  if (entries.length === 0) {
    return "";
  }
  const search = new URLSearchParams(
    entries.map(([key, value]) => [key, String(value)]),
  );
  return `?${search.toString()}`;
}

async function parse(response: Response): Promise<unknown> {
  const body = await response.text();
  if (body === "") {
    return null;
  }
  try {
    return JSON.parse(body) as unknown;
  } catch {
    throw new UnexpectedResponseError(
      response.status,
      `応答を読めませんでした: ${response.status}`, // 開発者向け
    );
  }
}

async function send(
  method: string,
  path: string,
  options: RequestOptions,
): Promise<unknown> {
  const url = `${API_BASE_PATH}${path}${queryString(options.query)}`;
  const response = await fetch(url, {
    method,
    credentials: "same-origin",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...(options.headers ?? {}),
    },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
    signal: options.signal,
  });

  const parsed = await parse(response);

  if (response.ok) {
    traceInfo("api.request", { method, path, status: response.status });
    return parsed;
  }

  throw failureOf(response, parsed, method, path);
}

function failureOf(
  response: Response,
  parsed: unknown,
  method: string,
  path: string,
): Error {
  if (isApiErrorResponse(parsed)) {
    const error = new ApiError(response.status, parsed.error);
    traceError("api.request", error, { method, path, status: response.status });
    return error;
  }

  const error = new UnexpectedResponseError(
    response.status,
    `契約の形ではない失敗です: ${response.status}`, // 開発者向け
  );
  traceError("api.request", error, { method, path, status: response.status });
  return error;
}

export function apiGet<T>(path: string, options: RequestOptions = {}): Promise<T> {
  return send("GET", path, options) as Promise<T>;
}

export function apiPost<T>(path: string, options: RequestOptions = {}): Promise<T> {
  return send("POST", path, options) as Promise<T>;
}

export function apiPatch<T>(path: string, options: RequestOptions = {}): Promise<T> {
  return send("PATCH", path, options) as Promise<T>;
}
