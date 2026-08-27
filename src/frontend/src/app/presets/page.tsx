import type { Metadata } from "next";
import { AppShell } from "@/components/app/AppShell";
import { Presets } from "@/components/presets";
import { text } from "@/strings";

export const metadata: Metadata = {
  title: text("presets.labels.title"),
};

/** プリセット（07）です（issue #75）。 */
export default function PresetsPage() {
  return (
    <AppShell active="presets">
      <Presets />
    </AppShell>
  );
}
