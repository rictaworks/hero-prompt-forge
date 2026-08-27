"use client";

import { useEffect, useState } from "react";
import { apiGet } from "@/lib/api";
import { text } from "@/strings";

/** サーバーが返す、ログイン中の利用者です。 */
interface SessionBody {
  display_name: string;
  plan: string;
}

export interface Session {
  displayName: string;
  plan: string;
  /** 上部バーに出す表記です。 */
  planLabel: string;
}

/**
 * ログイン中の利用者を引きます。
 *
 * **失敗を握りつぶしません。** 呼び出す側が受け取り、画面で伝えます。
 */
export function useSession(): { session: Session | null; error: unknown } {
  const [session, setSession] = useState<Session | null>(null);
  const [error, setError] = useState<unknown>(null);

  useEffect(() => {
    const controller = new AbortController();

    apiGet<SessionBody>("/session", { signal: controller.signal })
      .then((body) => setSession(toSession(body)))
      .catch((cause) => {
        if (controller.signal.aborted) {
          return;
        }
        setError(cause);
      });

    return () => controller.abort();
  }, []);

  return { session, error };
}

function toSession(body: SessionBody): Session {
  return {
    displayName: body.display_name,
    plan: body.plan,
    planLabel: `${text("nav.planPrefix")}${body.plan.toUpperCase()}`,
  };
}
