import type { Metadata } from "next";
import { Suspense } from "react";
import { AppShell } from "@/components/app/AppShell";
import { NewRequestForm } from "@/components/requests/NewRequestForm";
import { text } from "@/strings";

export const metadata: Metadata = {
  title: text("newRequest.labels.title"),
};

/**
 * 入力フォーム（03）です（issue #71、#152）。
 *
 * **問い合わせの文字列を読みますので、境目を置きます。** 置かないと、
 * 画面全体が組み立てのときに静的にできません。
 */
export default function NewRequestPage() {
  return (
    <AppShell active="newRequest">
      <Suspense fallback={<p>{text("newRequest.loading")}</p>}>
        <NewRequestForm />
      </Suspense>
    </AppShell>
  );
}
