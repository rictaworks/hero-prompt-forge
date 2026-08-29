"use client";

import { UnexpectedErrorNotice } from "@/components/feedback";
import { Button } from "@/components/ui";
import { traceError } from "@/lib/logger";
import { text } from "@/strings";
import styles from "@/components/app/app-shell.module.css";

/**
 * 想定していない失敗の逃がし先です（PR #174 のレビュー・要修正 6）。
 *
 * **曖昧なエラーを出しません**（issue #76）。逃がし先が無いと、画面全体が
 * 組み立ての素の失敗画面になり、何が起きたのかも、次に何をすればよいのかも
 * 分かりません。
 *
 * **握りつぶしません。** 記録へ残したうえで、画面でお伝えします。
 */
export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  traceError("app.unexpected", error, { digest: error.digest ?? "" });

  return (
    <div className={styles.page}>
      <main className={styles.main}>
        <UnexpectedErrorNotice traceId={error.digest} />
        <div>
          <Button variant="outline" onClick={reset}>
            {retryLabel()}
          </Button>
        </div>
      </main>
    </div>
  );
}

/** 文言は設定から引きます。 */
function retryLabel(): string {
  return text("errors.labels.retry");
}
