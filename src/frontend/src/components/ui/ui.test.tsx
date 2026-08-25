import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import {
  Button,
  FaqItem,
  Logo,
  ProcessStep,
  SectionHeading,
  StrengthCard,
} from "@/components/ui";

describe("Logo", () => {
  it("ワードマークと移動先を表示します", () => {
    render(<Logo wordmark="Veyra Dragon" href="/" />);

    expect(screen.getByRole("link", { name: /Veyra Dragon/ })).toHaveAttribute(
      "href",
      "/",
    );
  });

  it("ワードマークを隠せます", () => {
    render(<Logo wordmark="Veyra Dragon" showWordmark={false} />);

    expect(screen.queryByText("Veyra Dragon")).toBeNull();
  });
});

describe("Button", () => {
  it("移動先があるときは移動として描画します", () => {
    render(
      <Button href="/projects" variant="solid">
        Xでログイン
      </Button>,
    );

    expect(screen.getByRole("link", { name: "Xでログイン" })).toHaveAttribute(
      "href",
      "/projects",
    );
  });

  it("移動先が無いときは操作として描画します", () => {
    render(<Button>送信する</Button>);

    expect(screen.getByRole("button", { name: "送信する" })).toHaveAttribute(
      "type",
      "button",
    );
  });

  it("submit のときは送信の操作になります", () => {
    render(<Button variant="submit">送信する</Button>);

    expect(screen.getByRole("button", { name: "送信する" })).toHaveAttribute(
      "type",
      "submit",
    );
  });

  it("押せない状態のときは移動先を張りません", () => {
    render(
      <Button href="/projects" disabled>
        Xでログイン
      </Button>,
    );

    expect(screen.queryByRole("link")).toBeNull();
    expect(screen.getByRole("button", { name: "Xでログイン" })).toBeDisabled();
  });

  it("押したときの動きを受け取れます", async () => {
    const onClick = jest.fn();
    render(<Button onClick={onClick}>送信する</Button>);

    await userEvent.click(screen.getByRole("button", { name: "送信する" }));

    expect(onClick).toHaveBeenCalledTimes(1);
  });
});

describe("SectionHeading", () => {
  it("見出しと説明を表示します", () => {
    render(
      <SectionHeading eyebrow="WHAT WE DO" title="Three Guards">
        3つの規則を通過します。
      </SectionHeading>,
    );

    expect(screen.getByRole("heading", { name: "Three Guards" })).toBeVisible();
    expect(screen.getByText("WHAT WE DO")).toBeVisible();
    expect(screen.getByText("3つの規則を通過します。")).toBeVisible();
  });

  it("説明が無い場合は本文を出しません", () => {
    const { container } = render(<SectionHeading title="FAQ" />);

    expect(container.querySelector("p")).toBeNull();
  });
});

describe("StrengthCard", () => {
  it("題と本文を表示します", () => {
    render(
      <StrengthCard icon="bolt" title="Photographic Spec">
        撮影指示を必ず含めます。
      </StrengthCard>,
    );

    expect(
      screen.getByRole("heading", { name: "Photographic Spec" }),
    ).toBeVisible();
    expect(screen.getByText("撮影指示を必ず含めます。")).toBeVisible();
  });
});

describe("ProcessStep", () => {
  it("番号と題と本文を表示します", () => {
    render(
      <ProcessStep step="01" stepLabel="Step" icon="comments" title="Input">
        3項目を選びます。
      </ProcessStep>,
    );

    expect(screen.getByText("01")).toBeVisible();
    expect(screen.getByRole("heading", { name: "Input" })).toBeVisible();
    expect(screen.getByText("3項目を選びます。")).toBeVisible();
  });
});

describe("FaqItem", () => {
  it("初期状態は閉じています", () => {
    render(
      <FaqItem id="faq-1" question="Q. 日本語で入力できますか？">
        入力できます。
      </FaqItem>,
    );

    expect(screen.getByRole("button")).toHaveAttribute("aria-expanded", "false");
  });

  it("押すと開きます", async () => {
    render(
      <FaqItem id="faq-1" question="Q. 日本語で入力できますか？">
        入力できます。
      </FaqItem>,
    );

    await userEvent.click(screen.getByRole("button"));

    expect(screen.getByRole("button")).toHaveAttribute("aria-expanded", "true");
  });

  it("もう一度押すと閉じます", async () => {
    render(
      <FaqItem id="faq-1" question="Q. 日本語で入力できますか？" defaultOpen>
        入力できます。
      </FaqItem>,
    );

    await userEvent.click(screen.getByRole("button"));

    expect(screen.getByRole("button")).toHaveAttribute("aria-expanded", "false");
  });

  it("答えと質問を結び付けます", () => {
    render(
      <FaqItem id="faq-1" question="Q. 日本語で入力できますか？">
        入力できます。
      </FaqItem>,
    );

    expect(screen.getByRole("button")).toHaveAttribute(
      "aria-controls",
      "faq-1-answer",
    );
    expect(screen.getByRole("region")).toHaveAttribute("id", "faq-1-answer");
  });
});
