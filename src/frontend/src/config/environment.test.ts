import {
  currentEnvironment,
  developerShortcutsAllowed,
  UnknownEnvironmentError,
} from "@/config/environment";

describe("environment", () => {
  const original = process.env.NEXT_PUBLIC_APP_ENV;

  afterEach(() => {
    process.env.NEXT_PUBLIC_APP_ENV = original;
  });

  it("設定された環境名を返します", () => {
    process.env.NEXT_PUBLIC_APP_ENV = "development";

    expect(currentEnvironment()).toBe("development");
  });

  it("未知の値なら例外にします", () => {
    process.env.NEXT_PUBLIC_APP_ENV = "staging";

    expect(() => currentEnvironment()).toThrow(UnknownEnvironmentError);
  });

  it("未設定なら例外にします", () => {
    delete process.env.NEXT_PUBLIC_APP_ENV;

    expect(() => currentEnvironment()).toThrow(UnknownEnvironmentError);
  });

  it("本番では開発向けの近道を許しません", () => {
    process.env.NEXT_PUBLIC_APP_ENV = "production";

    expect(developerShortcutsAllowed()).toBe(false);
  });

  it("開発環境では開発向けの近道を許します", () => {
    process.env.NEXT_PUBLIC_APP_ENV = "development";

    expect(developerShortcutsAllowed()).toBe(true);
  });
});
