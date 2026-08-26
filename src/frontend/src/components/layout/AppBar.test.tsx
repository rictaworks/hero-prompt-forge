import { render, screen } from "@testing-library/react";

import { AppBar } from "@/components/layout/AppBar";
import {
  linkTo,
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

    // **名前を書き写しません。** 設定から引きます。
    expect(
      screen.getByRole("link", { name: new RegExp(text("app.wordmark")) }),
    ).toHaveAttribute(
      "href",
      "/",
    );
  });

  // **未実装の画面へは導線を張りません。** 開いても何も無い状態を作りません。
  // **一覧（`SCREENS`）が正です。** ここへ画面の名前を書き写しません。
  it("未実装の画面へは導線を張りません", () => {
    render(<AppBar plan="PLAN · ACTIVE" user="@ao_design" />);

    for (const key of ["projects", "presets"] as const) {
      const label = text(`nav.${key}.en`);
      const found = screen.queryByRole("link", { name: new RegExp(label) });

      expect([label, found === null]).toEqual([label, linkTo(key) === null]);
    }
  });

  it("実装済みの画面へは移動先を張ります", () => {
    render(<AppBar plan="PLAN · ACTIVE" user="@ao_design" />);

    expect(
      screen.getByRole("link", { name: new RegExp(text("nav.projects.en")) }),
    ).toHaveAttribute("href", linkTo("projects") ?? "");
  });

  // **一般の利用者の画面に、管理の導線を出しません**（issue #77）。
  it("管理への導線を出しません", () => {
    render(<AppBar plan="PLAN · ACTIVE" user="@ao_design" />);

    expect(screen.queryByText(text("nav.admin.en"))).toBeNull();
    expect(screen.queryByText(text("nav.admin.ja"))).toBeNull();
    expect(screen.queryByRole("link", { name: /admin/i })).toBeNull();
  });

  it("画面の名前は、実装の有無にかかわらず表示します", () => {
    render(<AppBar plan="PLAN · ACTIVE" user="@ao_design" />);

    expect(screen.getByText("Projects")).toBeVisible();
    expect(screen.getByText("プロジェクト")).toBeVisible();
  });

  // **一覧（`SCREENS`）が正です。** 実装の有無を、ここへ書き写しません。
  it("新規生成は、実装済みなら移動先を張り、未実装なら押せません", () => {
    render(<AppBar plan="PLAN · ACTIVE" user="@ao_design" />);

    const label = text("nav.newRequest.action");

    const path = linkTo("newRequest");

    if (path !== null) {
      expect(screen.getByRole("link", { name: label })).toHaveAttribute(
        "href",
        path,
      );
    } else {
      expect(screen.getByRole("button", { name: label })).toBeDisabled();
    }
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

  // **識別子で決まる画面は、固定の入口を持ちません。**
  // 実装済みかどうかを `path` の有無で表すと、この 3 画面が永久に未実装になります。
  it("識別子で決まる画面は、実装済みでも固定の入口を持ちません", () => {
    for (const key of ["generating", "result"] as const) {
      expect([key, screenOf(key).implemented, linkTo(key)]).toEqual([key, true, null]);
    }
  });

  it("未定義の画面を求めると例外にします", () => {
    // @ts-expect-error 未定義の識別子を渡した場合の振る舞いを確認します。
    expect(() => screenOf("nothing")).toThrow(UnknownScreenError);
  });
});
