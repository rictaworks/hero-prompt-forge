import type { Metadata } from "next";
import { Landing } from "@/components/landing";
import { text } from "@/strings";

export const metadata: Metadata = {
  title: text("landing.meta.title"),
  description: text("app.description"),
};

export default function Home() {
  return <Landing />;
}
