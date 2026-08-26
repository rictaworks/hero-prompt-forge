import type { Metadata } from "next";
import { AppShell } from "@/components/app/AppShell";
import { RequestNotes } from "@/components/requests/RequestNotes";
import { text } from "@/strings";

export const metadata: Metadata = {
  title: text("evaluation.labels.title"),
};

/** 評価メモ（06）です（issue #74）。 */
export default async function NotesPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  return (
    <AppShell>
      <RequestNotes id={id} />
    </AppShell>
  );
}
