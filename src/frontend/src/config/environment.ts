/**
 * 実行中の環境を判定します。
 *
 * 環境ごとの分岐は、必ずこのモジュールを通します。環境変数を各所で直接読むと、
 * 判定の条件が散らばって追えなくなるためです。
 *
 * 未設定・未知の値は例外にします。既定値へ寄せると、本番で開発向けの分岐が
 * 有効になっていても気づけないためです。
 */
export const APP_ENVIRONMENTS = ["development", "test", "production"] as const;

export type AppEnvironment = (typeof APP_ENVIRONMENTS)[number];

export class UnknownEnvironmentError extends Error {}

function isAppEnvironment(value: string | undefined): value is AppEnvironment {
  return (
    value !== undefined &&
    (APP_ENVIRONMENTS as readonly string[]).includes(value)
  );
}

export function currentEnvironment(): AppEnvironment {
  const value = process.env.NEXT_PUBLIC_APP_ENV;
  if (!isAppEnvironment(value)) {
    throw new UnknownEnvironmentError(
      `NEXT_PUBLIC_APP_ENV が不正です: ${String(value)}`, // 開発者向け
    );
  }
  return value;
}

export function isDevelopment(): boolean {
  return currentEnvironment() === "development";
}

export function isProduction(): boolean {
  return currentEnvironment() === "production";
}

/** 開発向けの近道を有効にしてよい環境かどうかを返します。本番では必ず false です。 */
export function developerShortcutsAllowed(): boolean {
  const env = currentEnvironment();
  return env === "development" || env === "test";
}
