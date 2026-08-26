"use client";

import type { ReactNode } from "react";
import { AppBar } from "@/components/layout/AppBar";
import { UnexpectedErrorNotice } from "@/components/feedback";
import { useSession } from "@/hooks/useSession";
import type { ScreenKey } from "@/config/screens";
import styles from "./app-shell.module.css";

export interface AppShellProps {
  /** 現在地です。 */
  active?: ScreenKey;
  children: ReactNode;
}

/**
 * ログインしたあとの画面の外枠です。
 *
 * **上部バーの表示名とプラン値は、その都度サーバーから引きます。**
 * 画面へ値を持たせません。持たせると、他の端末で変わった値が反映されません。
 *
 * **読み込みの間は、上部バーの値を空にします。** 仮の値を出しません。
 * 仮の値は、実際の値と違っていても気づけません。
 */
export function AppShell({ active, children }: AppShellProps) {
  const { session, error } = useSession();

  return (
    <div className={styles.page}>
      <AppBar
        active={active}
        plan={session ? session.planLabel : ""}
        user={session ? session.displayName : ""}
      />
      <main className={styles.main}>
        {error ? <UnexpectedErrorNotice /> : null}
        {children}
      </main>
    </div>
  );
}
