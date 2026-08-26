import type { Metadata } from "next";
import { Landing } from "@/components/landing";
import { publicBaseUrl } from "@/config/site";
import { text } from "@/strings";

/**
 * 共有されたときの見え方です（OGP）。
 *
 * **B2B の公開画面です。** X で共有される前提ですので、題・説明・画像・
 * 正となる場所を明示します（PR #170 のレビューより）。
 */
export const metadata: Metadata = {
  metadataBase: new URL(publicBaseUrl()),
  title: text("landing.meta.title"),
  description: text("app.description"),
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    url: "/",
    title: text("landing.meta.title"),
    description: text("landing.meta.shareDescription"),
    images: [{ url: "/images/hero-background.webp" }],
  },
  twitter: {
    card: "summary_large_image",
    title: text("landing.meta.title"),
    description: text("landing.meta.shareDescription"),
    images: ["/images/hero-background.webp"],
  },
};

export default function Home() {
  return <Landing />;
}
