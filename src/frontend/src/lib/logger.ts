/**
 * 追跡できる記録を残します。
 *
 * - どの処理で、どの値を扱い、何が起きたかを1行ずつ残します
 * - 例外を握りつぶしません。記録したうえで呼び出し元へ投げ直します
 * - 秘匿値を渡しません。渡す値は追跡に必要なものだけにします
 */
export type TraceContext = Record<string, string | number | boolean | null>;

function format(context: TraceContext): string {
  return Object.entries(context)
    .map(([key, value]) => `${key}=${JSON.stringify(value)}`)
    .join(" ");
}

export function traceInfo(name: string, context: TraceContext = {}): void {
  console.info(`[trace] ${name} ${format(context)}`);
}

export function traceError(
  name: string,
  error: unknown,
  context: TraceContext = {},
): void {
  const message = error instanceof Error ? `${error.name}: ${error.message}` : String(error);
  console.error(`[trace] ${name} 失敗 ${format(context)} error=${message}`);
}

/** 処理を包んで、開始・完了・失敗を記録します。例外はそのまま投げ直します。 */
export async function traceStep<T>(
  name: string,
  context: TraceContext,
  run: () => Promise<T>,
): Promise<T> {
  traceInfo(name, context);
  try {
    const result = await run();
    traceInfo(`${name} 完了`, context);
    return result;
  } catch (error) {
    traceError(name, error, context);
    throw error;
  }
}
