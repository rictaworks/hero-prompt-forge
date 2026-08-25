import type { Metadata } from "next";
import "@fortawesome/fontawesome-free/css/all.min.css";
import "@/styles/tokens/index.css";
import { montserrat, notoSansJp } from "@/app/fonts";
import { text } from "@/strings";

export const metadata: Metadata = {
  title: text("app.title"),
  description: text("app.description"),
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ja" className={`${montserrat.variable} ${notoSansJp.variable}`}>
      <body>{children}</body>
    </html>
  );
}
