import Link from "next/link";
import { Button, Logo } from "@/components/ui";
import { linkTo, type ScreenKey } from "@/config/screens";
import { text } from "@/strings";
import styles from "./AppBar.module.css";

/**
 * 上部バーに並べる項目です。
 *
 * **管理（09）を並べません**（issue #77、requirements.md 4.3、CLAUDE.md）。
 * 管理画面は開発者用で、入口そのものを分けています（Rails 側・BASIC 認証）。
 * **一般の利用者の画面に、管理の導線を出しません。**
 *
 * **モックには「Admin 管理」が並んでいます**（`app-ui/scripts/chrome.js`）。
 * **モックは書き換えません。** 実装側で、この 1 点だけを意図して外します。
 */
const NAV_ITEMS: readonly ScreenKey[] = ["projects", "presets"];

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
            const path = linkTo(key);
            const label = text(`nav.${key}.en`);
            const sublabel = text(`nav.${key}.ja`);
            const isActive = active === key;

            const content = (
              <>
                <span className={styles.navEn}>{label}</span>
                <span className={styles.navJa}>{sublabel}</span>
              </>
            );

            if (path === null) {
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
                href={path}
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
          href={linkTo("newRequest") ?? undefined}
          disabled={linkTo("newRequest") === null}
        >
          {text("nav.newRequest.action")}
        </Button>
      </div>
    </header>
  );
}
