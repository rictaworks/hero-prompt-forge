"use client";

import { useEffect, useState } from "react";
import { apiGet } from "@/lib/api";
import { PENDING_STATUSES, type PromptRequestDetail } from "@/types/resources";

/**
 * 生成リクエストの状態を、結果が出るまで取りに行きます（issue #56、#72）。
 *
 * **まだ動いている間だけ、取りに行き続けます。** 決着した状態になったら
 * 止めます。止めないと、開いたままの画面が問い合わせを出し続けます。
 *
 * **失敗を握りつぶしません。** 呼び出す側が受け取り、画面で伝えます。
 */

/** 取りに行く間隔です。 */
export const POLL_INTERVAL_MS = 2000;

export interface RequestState {
  request: PromptRequestDetail | null;
  error: unknown;
  /** まだ動いている状態かどうかです。 */
  pending: boolean;
}

export function useRequest(id: string): RequestState {
  const [request, setRequest] = useState<PromptRequestDetail | null>(null);
  const [error, setError] = useState<unknown>(null);

  useEffect(() => {
    const controller = new AbortController();
    let timer: ReturnType<typeof setTimeout> | null = null;

    const fetchOnce = (): void => {
      apiGet<PromptRequestDetail>(`/prompt_requests/${id}`, {
        signal: controller.signal,
      })
        .then((found) => {
          setRequest(found);
          if (PENDING_STATUSES.includes(found.status)) {
            timer = setTimeout(fetchOnce, POLL_INTERVAL_MS);
          }
        })
        .catch((cause) => {
          if (controller.signal.aborted) {
            return;
          }
          setError(cause);
        });
    };

    fetchOnce();

    return () => {
      controller.abort();
      if (timer !== null) {
        clearTimeout(timer);
      }
    };
  }, [id]);

  return {
    request,
    error,
    pending: request === null || PENDING_STATUSES.includes(request.status),
  };
}
