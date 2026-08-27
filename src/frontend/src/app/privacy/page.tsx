import type { Metadata } from "next";
import { LegalPage } from "@/components/legal";
import { text } from "@/strings";

export const metadata: Metadata = {
  title: text("legal.labels.privacyTitle"),
};

/** 法務ページです（issue #171、#172）。**ログインの前に読めます。** */
export default function Page() {
  return <LegalPage which="privacy" />;
}
