import { render, screen } from "@testing-library/react";

import { AppBar } from "@/components/layout/AppBar";
import {
  isImplemented,
  SCREENS,
  screenOf,
  UnknownScreenError,
} from "@/config/screens";
import { text } from "@/strings";

describe("AppBar", () => {
  it("プラン値と利用者名を表示します", () => {
    render(<AppBar plan="PLAN · ACTIVE" user="@ao_design" />);

    expect(screen.getByText("PLAN · ACTIVE")).toBeVisible();
    expect(screen.getByText("@ao_design")).toBeVisible();
  });

  it("ロゴから先頭の画面へ移動できます", () => {
    render(<AppBar plan="PLAN · ACTIVE" user="@ao_design" />);

    expect(screen.getByRole("link", { name: /Veyra Dragon/ })).toHaveAttribute(
      "href",
      "/",
    );
  });

  // **未実装の画面へは導線を張りません。** 開いても何も無い状態を作りません。
  // **一覧（`SCREENS`）が正です。** ここへ画面の名前を書き写しません。
  it("未実装の画面へは導線を張りません", () => {
    render(<AppBar plan="PLAN · ACTIVE" user="@ao_design" />);

    for (const key of ["projects", "presets", "admin"] as const) {
      const label = text(`nav.${key}.en`);
      const found = screen.queryByRole("link", { name: new RegExp(label) });

      expect([label, found === null]).toEqual([label, !isImplemented(key)]);
    }
  });

  it("実装済みの画面へは移動先を張ります", () => {
    render(<AppBar plan="PLAN · ACTIVE" user="@ao_design" />);

    expect(
      screen.getByRole("link", { name: new RegExp(text("nav.projects.en")) }),
    ).toHaveAttribute("href", screenOf("projects").path ?? "");
  });

  it("画面の名前は、実装の有無にかかわらず表示します", () => {
    render(<AppBar plan="PLAN · ACTIVE" user="@ao_design" />);

    expect(screen.getByText("Projects")).toBeVisible();
    expect(screen.getByText("プロジェクト")).toBeVisible();
  });

  it("新規生成は未実装のため押せません", () => {
    render(<AppBar plan="PLAN · ACTIVE" user="@ao_design" />);

    expect(screen.getByRole("button", { name: "新規生成" })).toBeDisabled();
  });
});

describe("画面の一覧", () => {
  it("モックの9画面をすべて持ちます", () => {
    expect(SCREENS).toHaveLength(9);
  });

  it("番号が 01 から 09 まで連番です", () => {
    expect(SCREENS.map((s) => s.no)).toEqual([
      "01",
      "02",
      "03",
      "04",
      "05",
      "06",
      "07",
      "08",
      "09",
    ]);
  });

  it("未定義の画面を求めると例外にします", () => {
    // @ts-expect-error 未定義の識別子を渡した場合の振る舞いを確認します。
    expect(() => screenOf("nothing")).toThrow(UnknownScreenError);
  });
});
