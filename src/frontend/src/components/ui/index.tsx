"use client";

import Link from "next/link";
import { useState } from "react";
import type { ButtonHTMLAttributes, ReactNode } from "react";
import styles from "./ui.module.css";

/* ── Logo ─────────────────────────────────────────────────── */

export interface LogoProps {
  href?: string;
  size?: "default" | "sm";
  wordmark: string;
  showWordmark?: boolean;
}

/** ブランドの表示です。app-ui の Logo と同じ体裁です。 */
export function Logo({
  href = "/",
  size = "default",
  wordmark,
  showWordmark = true,
}: LogoProps) {
  const className =
    size === "sm" ? `${styles.logo} ${styles.logoSmall}` : styles.logo;

  return (
    <Link href={href} className={className}>
      <span className={styles.logoDisc}>
        <i className="fa-solid fa-dragon" aria-hidden="true" />
      </span>
      {showWordmark ? <span>{wordmark}</span> : null}
    </Link>
  );
}

/* ── Button ───────────────────────────────────────────────── */

export type ButtonVariant = "outline" | "solid" | "submit";

export interface ButtonProps
  extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, "type"> {
  variant?: ButtonVariant;
  href?: string;
  icon?: string;
  iconPosition?: "start" | "end";
  fullWidth?: boolean;
  /**
   * 画面の外へ出る入口かどうかです。
   *
   * **外への出口では、画面の中の移動の仕組みを使いません。**
   * その仕組みは、移動先を先に読み込みます。**押していないのに
   * 呼ばれますので、ログインの手続きが勝手に始まります**
   * （PR #170 のレビューで実測されました）。
   */
  external?: boolean;
  children: ReactNode;
}

/**
 * 押せるものの表示です。app-ui の Button と同じ体裁です。
 *
 * href を渡した場合は移動、渡さない場合は操作として描画します。
 * 押せない状態のときは移動先を張りません。
 *
 * **外への出口（`external`）では、素の入口を描きます。** 先読みを
 * 起こしません。
 */
export function Button({
  variant = "outline",
  href,
  icon,
  iconPosition = "end",
  fullWidth = false,
  external = false,
  disabled = false,
  children,
  className,
  ...rest
}: ButtonProps) {
  const classes = [
    styles.button,
    styles[variant],
    fullWidth ? styles.fullWidth : "",
    className ?? "",
  ]
    .filter(Boolean)
    .join(" ");

  const glyph = icon ? (
    <i className={`fa-solid fa-${icon}`} aria-hidden="true" />
  ) : null;

  const content = (
    <>
      {iconPosition === "start" ? glyph : null}
      <span>{children}</span>
      {iconPosition === "end" ? glyph : null}
    </>
  );

  if (href && !disabled) {
    // **外への出口は、素の入口で描きます。** 先読みを起こしません。
    return external ? (
      <a href={href} className={classes}>
        {content}
      </a>
    ) : (
      <Link href={href} className={classes}>
        {content}
      </Link>
    );
  }

  return (
    <button
      type={variant === "submit" ? "submit" : "button"}
      className={classes}
      disabled={disabled}
      {...rest}
    >
      {content}
    </button>
  );
}

/* ── SectionHeading ───────────────────────────────────────── */

export type SectionHeadingSize = "default" | "sm" | "contact" | "band";

export interface SectionHeadingProps {
  eyebrow?: string;
  title: ReactNode;
  size?: SectionHeadingSize;
  divider?: boolean;
  align?: "left" | "center";
  children?: ReactNode;
}

const SIZE_CLASS: Record<SectionHeadingSize, string> = {
  default: styles.sizeDefault,
  sm: styles.sizeSm,
  contact: styles.sizeContact,
  band: styles.sizeBand,
};

/** 見出しの組です。app-ui の SectionHeading と同じ体裁です。 */
export function SectionHeading({
  eyebrow,
  title,
  size = "default",
  divider = true,
  align = "left",
  children,
}: SectionHeadingProps) {
  return (
    <div className={align === "center" ? styles.alignCenter : undefined}>
      {eyebrow ? <p className={styles.eyebrow}>{eyebrow}</p> : null}
      <h2 className={`${styles.headingTitle} ${SIZE_CLASS[size]}`}>{title}</h2>
      {divider ? (
        <div
          className={
            align === "center"
              ? `${styles.divider} ${styles.dividerCenter}`
              : styles.divider
          }
        />
      ) : null}
      {children ? <p className={styles.headingBody}>{children}</p> : null}
    </div>
  );
}

/* ── StrengthCard ─────────────────────────────────────────── */

export interface StrengthCardProps {
  icon?: string;
  title: string;
  children: ReactNode;
}

/** 特徴を並べる札です。app-ui の StrengthCard と同じ体裁です。 */
export function StrengthCard({ icon, title, children }: StrengthCardProps) {
  return (
    <article className={styles.card}>
      {icon ? (
        <div className={styles.cardIcon}>
          <i className={`fa-solid fa-${icon}`} aria-hidden="true" />
        </div>
      ) : null}
      <h3 className={styles.cardTitle}>{title}</h3>
      <p className={styles.cardBody}>{children}</p>
    </article>
  );
}

/* ── ProcessStep ──────────────────────────────────────────── */

export interface ProcessStepProps {
  step: string;
  stepLabel: string;
  icon: string;
  title: string;
  children: ReactNode;
}

/** 手順の1段です。app-ui の ProcessStep と同じ体裁です。 */
export function ProcessStep({
  step,
  stepLabel,
  icon,
  title,
  children,
}: ProcessStepProps) {
  return (
    <div className={styles.step}>
      <div className={styles.stepLabel}>
        {stepLabel}
        <span className={styles.stepNumber}>{step}</span>
      </div>
      <div className={styles.stepRail}>
        <div className={styles.stepDisc}>
          <i className={`fa-solid fa-${icon}`} aria-hidden="true" />
        </div>
      </div>
      <div className={styles.stepContent}>
        <h3 className={styles.stepTitle}>{title}</h3>
        <p className={styles.stepBody}>{children}</p>
      </div>
    </div>
  );
}

/* ── FaqItem ──────────────────────────────────────────────── */

export interface FaqItemProps {
  id: string;
  question: string;
  defaultOpen?: boolean;
  children: ReactNode;
}

/**
 * よくある質問の1件です。app-ui の FaqItem と同じ体裁です。
 * 開閉は各項目が個別に持ちます。初期状態は閉じています。
 */
export function FaqItem({
  id,
  question,
  defaultOpen = false,
  children,
}: FaqItemProps) {
  const [open, setOpen] = useState(defaultOpen);
  const answerId = `${id}-answer`;

  return (
    <div className={styles.faqItem}>
      <button
        type="button"
        className={styles.faqQuestion}
        aria-expanded={open}
        aria-controls={answerId}
        onClick={() => setOpen(!open)}
      >
        <span>{question}</span>
        <i
          className={`fa-solid fa-chevron-down ${styles.faqChevron}`}
          aria-hidden="true"
        />
      </button>
      <div
        id={answerId}
        role="region"
        className={
          open ? `${styles.faqAnswer} ${styles.faqAnswerOpen}` : styles.faqAnswer
        }
      >
        <p>{children}</p>
      </div>
    </div>
  );
}
