import Link from "next/link";
import { Button, Logo } from "@/components/ui";
import { screenOf, type ScreenKey } from "@/config/screens";
import { text } from "@/strings";
import styles from "./AppBar.module.css";

/** 上部バーに並べる項目です。 */
const NAV_ITEMS: readonly ScreenKey[] = ["projects", "presets", "admin"];

export interface AppBarProps {
  /** 現在地です。どこにも該当しない場合は渡しません。 */
  active?: ScreenKey;
  /** プラン値の表示です。 */
  plan: string;
  /** 利用者の表示名です。 */
  user: string;
}

/**
 * アプリ内画面の上部バーです。app-ui の HPFAppBar と同じ体裁です。
 *
 * 未実装の画面へは導線を張りません。開いても何も無い状態を作らないためです。
 */
export function AppBar({ active, plan, user }: AppBarProps) {
  return (
    <header className={styles.appBar}>
      <div className={styles.left}>
        <Logo href="/" wordmark={text("app.wordmark")} />
        <nav className={styles.nav}>
          {NAV_ITEMS.map((key) => {
            const screen = screenOf(key);
            const label = text(`nav.${key}.en`);
            const sublabel = text(`nav.${key}.ja`);
            const isActive = active === key;

            const content = (
              <>
                <span className={styles.navEn}>{label}</span>
                <span className={styles.navJa}>{sublabel}</span>
              </>
            );

            if (screen.path === null) {
              return (
                <span
                  key={key}
                  className={`${styles.navItem} ${styles.navItemPending}`}
                >
                  {content}
                </span>
              );
            }

            return (
              <Link
                key={key}
                href={screen.path}
                className={
                  isActive
                    ? `${styles.navItem} ${styles.navItemActive}`
                    : styles.navItem
                }
                aria-current={isActive ? "page" : undefined}
              >
                {content}
              </Link>
            );
          })}
        </nav>
      </div>

      <div className={styles.right}>
        <span className={styles.plan}>{plan}</span>
        <span className={styles.user}>{user}</span>
        <Button
          variant="solid"
          icon="plus"
          iconPosition="start"
          href={screenOf("newRequest").path ?? undefined}
          disabled={screenOf("newRequest").path === null}
        >
          {text("nav.newRequest.action")}
        </Button>
      </div>
    </header>
  );
}
