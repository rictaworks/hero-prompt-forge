import type { Metadata } from "next";
import { AppShell } from "@/components/app/AppShell";
import { RequestResult } from "@/components/requests/RequestResult";
import { text } from "@/strings";

export const metadata: Metadata = {
  title: text("result.labels.title"),
};

/** 結果 3 案（05）です（issue #73）。 */
export default async function ResultPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  return (
    <AppShell>
      <RequestResult id={id} />
    </AppShell>
  );
}
