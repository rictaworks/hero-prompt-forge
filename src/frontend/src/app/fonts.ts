import { Montserrat, Noto_Sans_JP } from "next/font/google";

/**
 * 書体です。app-ui と同じ Montserrat（見出し・UI）と Noto Sans JP（本文）です。
 * 読み込む太さも app-ui の指定に合わせています。
 */
export const montserrat = Montserrat({
  subsets: ["latin"],
  weight: ["400", "600", "700", "800", "900"],
  variable: "--font-montserrat",
  display: "swap",
});

export const notoSansJp = Noto_Sans_JP({
  subsets: ["latin"],
  weight: ["300", "400", "500", "700"],
  variable: "--font-noto-sans-jp",
  display: "swap",
});
