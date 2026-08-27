import Image from "next/image";
import Link from "next/link";
import { Button, FaqItem, Logo, ProcessStep, SectionHeading, StrengthCard } from "@/components/ui";
import { LOGIN_PATH } from "@/config/backend";
import { text } from "@/strings";
import styles from "./landing.module.css";

/** 特徴の 3 枚です。文言は設定から引きます。 */
const CARDS = [
  { key: "antiCliche", icon: "shield-halved" },
  { key: "photographic", icon: "bolt" },
  { key: "copySpace", icon: "chart-line" },
] as const;

/** 手順の 4 段です。 */
const STEPS = [
  { key: "input", no: "01", icon: "comments" },
  { key: "rules", no: "02", icon: "chess-knight" },
  { key: "refine", no: "03", icon: "code" },
  { key: "packageStep", no: "04", icon: "handshake" },
] as const;

/** よくある質問の 3 件です。 */
const FAQS = ["images", "names", "japanese"] as const;

/** 画面の中の移動先です。 */
const ANCHORS = [
  { key: "features", label: "Features", href: "#features" },
  { key: "process", label: "Process", href: "#process" },
  { key: "faq", label: "Faq", href: "#faq" },
] as const;

/**
 * ランディング（01）です。
 *
 * `app-ui/index.html` の体裁をそのまま再現します。**モックを書き換えません。**
 * 文言は `src/strings/ja.ts` から引きます。**画面へ直書きしません。**
 */
export function Landing() {
  return (
    <div className={styles.page}>
      <header className={styles.nav}>
        <Logo wordmark={text("app.wordmark")} />
        <nav className={styles.navMenu}>
          {ANCHORS.map((anchor) => (
            <a key={anchor.key} className={styles.navLink} href={anchor.href}>
              {text(`landing.labels.nav${anchor.label}`)}
            </a>
          ))}
          <Button variant="solid" href={LOGIN_PATH} external>
            {text("landing.labels.navLogin")}
          </Button>
        </nav>
      </header>

      <HeroSection />
      <FeaturesSection />
      <ProcessSection />
      <FaqSection />
      <ContactSection />
      <FooterSection />
    </div>
  );
}

function HeroSection() {
  return (
    <section className={styles.hero}>
      <Image
        className={styles.heroImg}
        src="/images/hero-background.webp"
        alt={text("landing.labels.heroImageAlt")}
        fill
        priority
        sizes="100vw"
      />
      <div className={styles.heroScrim} />
      <div className={styles.heroInner}>
        <span className={styles.heroEyebrow}>{text("landing.labels.heroEyebrow")}</span>
        <h1 className={styles.heroTitle}>
          {text("landing.labels.heroTitleFirst")}
          <br />
          {text("landing.labels.heroTitleSecond")}
          <span className={styles.accent}>{text("landing.labels.heroTitleAccent")}</span>
        </h1>
        <p className={styles.heroLead}>{text("landing.hero.lead")}</p>
        <div className={styles.heroActions}>
          <Button variant="outline" href={LOGIN_PATH} icon="chevron-right" external>
            {text("landing.labels.heroAction")}
          </Button>
          {/* **アカウント名を立たせます。** 誰のフォロワーであればよいかは、
              利用できるかどうかの判断材料です（`app-ui/index.html` と同じ体裁）。 */}
          <span className={styles.heroNote}>
            {text("landing.labels.heroNoteBefore")}
            <span className={styles.heroNoteAccount}>
              {text("landing.labels.heroNoteAccount")}
            </span>
            {text("landing.labels.heroNoteAfter")}
            <br />
            {text("landing.labels.heroNoteTail")}
          </span>
        </div>
      </div>
      <div className={styles.heroScrollCue} />
    </section>
  );
}

function FeaturesSection() {
  return (
    <section className={`${styles.section} ${styles.sectionAlt}`} id="features">
      <SectionHeading
        eyebrow={text("landing.labels.featuresEyebrow")}
        title={text("landing.labels.featuresTitle")}
      >
        {text("landing.features.body")}
      </SectionHeading>
      <div className={styles.cards}>
        {CARDS.map((card) => (
          <StrengthCard
            key={card.key}
            icon={card.icon}
            title={text(`landing.features.cards.${card.key}.title`)}
          >
            {text(`landing.features.cards.${card.key}.body`)}
          </StrengthCard>
        ))}
      </div>
    </section>
  );
}

function ProcessSection() {
  return (
    <section className={styles.section} id="process">
      <SectionHeading
        eyebrow={text("landing.labels.processEyebrow")}
        title={text("landing.labels.processTitle")}
      >
        {text("landing.process.body")}
      </SectionHeading>
      <div className={styles.sectionBody}>
        {STEPS.map((step) => (
          <ProcessStep
            key={step.key}
            step={step.no}
            stepLabel={text("landing.labels.processStep")}
            icon={step.icon}
            title={text(`landing.process.steps.${step.key}.title`)}
          >
            {text(`landing.process.steps.${step.key}.body`)}
          </ProcessStep>
        ))}
      </div>
    </section>
  );
}

function FaqSection() {
  return (
    <section className={`${styles.section} ${styles.sectionAlt}`} id="faq">
      <SectionHeading
        eyebrow={text("landing.labels.faqEyebrow")}
        title={text("landing.labels.faqTitle")}
      />
      <div className={styles.sectionBody}>
        {FAQS.map((key, index) => (
          <FaqItem
            key={key}
            id={`faq-${index + 1}`}
            question={text(`landing.faq.items.${key}.question`)}
          >
            {text(`landing.faq.items.${key}.answer`)}
          </FaqItem>
        ))}
      </div>
    </section>
  );
}

/**
 * 画面の下の帯です（issue #172）。
 *
 * **モックには無い要素です**（`app-ui/index.html`）。**モックは書き換えません。**
 * 実装側で足します。
 *
 * **ログインの時点で Cookie を置きます。** 置く以上、利用者へ伝える必要が
 * あります。**規約とポリシーへ、ログインの前に辿れるようにします。**
 */
function FooterSection() {
  const pages = ["terms", "privacy", "commerce"] as const;

  return (
    <footer className={styles.footer}>
      <nav className={styles.footerLinks}>
        {pages.map((page) => (
          <Link key={page} className={styles.footerLink} href={`/${page}`}>
            {text(`landing.footer.labels.${page}`)}
          </Link>
        ))}
      </nav>
      <p className={styles.footerNote}>{text("landing.footer.note")}</p>
    </footer>
  );
}

function ContactSection() {
  return (
    <section className={styles.contact}>
      <Image
        className={styles.contactImg}
        src="/images/contact-background.webp"
        alt={text("landing.labels.contactImageAlt")}
        fill
        sizes="100vw"
      />
      <div className={styles.contactScrim} />
      <div className={styles.contactInner}>
        <SectionHeading
          eyebrow={text("landing.labels.contactEyebrow")}
          title={text("landing.contact.title")}
        >
          {text("landing.contact.body")}
        </SectionHeading>
        <div className={styles.contactCta}>
          <Button variant="submit" href={LOGIN_PATH} fullWidth external>
            {text("landing.labels.contactAction")}
          </Button>
        </div>
      </div>
    </section>
  );
}
