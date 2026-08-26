import type { Metadata } from "next";
import { AppShell } from "@/components/app/AppShell";
import { RequestStatus } from "@/components/requests/RequestStatus";
import { text } from "@/strings";

export const metadata: Metadata = {
  title: text("requestStatus.labels.title"),
};

/** 生成中（04）と、縮退・失敗・差し戻し（08）です（issue #72、#76）。 */
export default async function RequestPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  return (
    <AppShell>
      <RequestStatus id={id} />
    </AppShell>
  );
}
