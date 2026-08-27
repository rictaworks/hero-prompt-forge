import { SectionHeading } from "@/components/ui";
import { text } from "@/strings";
import { legal } from "@/strings/legal";
import styles from "./legal.module.css";

/**
 * 法務ページです（issue #171、#172）。
 *
 * **ログインの前に読めます。** 認証を求めません。利用条件と、取り扱う情報を
 * 知ってからお申し込みいただくためです。
 *
 * **本文は設定から読みます**（`src/strings/legal.ts`）。画面へ直書きしません。
 *
 * **Google への導線は、ここでリンクにします。** 本文へ URL を書きません。
 * 文言と場所を分けておくと、宛先が変わったときに本文へ触れずに済みます。
 */

/** 法務ページの種別です。 */
export type LegalKey = "terms" | "privacy" | "commerce";

/** Google の文書の場所です。**画面が持つ、外への出口です。** */
const GOOGLE_LINKS = {
  googleTerms: "https://policies.google.com/terms",
  googlePrivacy: "https://policies.google.com/privacy",
} as const;

export interface LegalPageProps {
  which: LegalKey;
}

export function LegalPage({ which }: LegalPageProps) {
  const document = legal[which];

  return (
    <div className={styles.page}>
      <main className={styles.main}>
        <SectionHeading
          eyebrow={text("legal.labels.updatedAtValue")}
          title={text(`legal.labels.${which}Title`)}
        >
          {document.intro}
        </SectionHeading>

        {document.articles.map((article) => (
          <section key={article.labels.heading} className={styles.article}>
            <h2 className={styles.heading}>{article.labels.heading}</h2>
            {article.paragraphs.map((paragraph, index) => (
              <p key={`${article.labels.heading}-${index}`} className={styles.paragraph}>
                {paragraph}
              </p>
            ))}
          </section>
        ))}

        {which === "privacy" ? <GoogleLinks /> : null}

        <Facts />
      </main>
    </div>
  );
}

/**
 * Google の文書への導線です。
 *
 * **reCAPTCHA v3 のバッジを隠す場合、Google は代わりの表示を求めます**
 * （issue #171）。**そのための導線です。**
 */
function GoogleLinks() {
  return (
    <section className={styles.article}>
      <ul className={styles.links}>
        {(Object.keys(GOOGLE_LINKS) as Array<keyof typeof GOOGLE_LINKS>).map((key) => (
          <li key={key}>
            {/* **外への出口です。** 画面の中の移動の仕組みを使いません。 */}
            <a href={GOOGLE_LINKS[key]} rel="noreferrer noopener" target="_blank">
              {text(`legal.labels.${key}`)}
            </a>
          </li>
        ))}
      </ul>
    </section>
  );
}

/** 提供者と連絡先です。**どのページにも出します。** */
function Facts() {
  const rows = [
    { key: "updatedAt", value: text("legal.labels.updatedAtValue") },
    { key: "provider", value: text("legal.labels.providerValue") },
    { key: "contact", value: text("legal.labels.contactValue") },
  ];

  return (
    <section className={styles.facts}>
      {rows.map((row) => (
        <div key={row.key} className={styles.factsRow}>
          <span className={styles.factsKey}>{text(`legal.labels.${row.key}`)}</span>
          <span className={styles.factsValue}>{row.value}</span>
        </div>
      ))}
    </section>
  );
}
