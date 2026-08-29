import { render, screen } from "@testing-library/react";

import { RequestRow } from "@/components/projects";
import { text } from "@/strings";
import type { PromptRequestSummary } from "@/types/resources";

function requestOf(overrides: Partial<PromptRequestSummary> = {}): PromptRequestSummary {
  return {
    id: 42,
    project_id: 7,
    status: "draft",
    degraded: false,
    target_model: "midjourney",
    dictionary_version: "v1",
    created_at: "2026-08-01T00:00:00+09:00",
    updated_at: "2026-08-01T00:00:00+09:00",
    outputs_count: 0,
    ...overrides,
  };
}

/**
 * 履歴・一覧（02）の「同じ条件で作り直す」です（issue #70）。
 *
 * **`request_id` を引き継がないと、入力フォームがどのリクエストから
 * 引き継ぐのかを見失います**（PR #174 のレビュー・重大 3）。
 */
describe("同じ条件で作り直す移動先", () => {
  it("request_id を含みます", () => {
    render(<RequestRow request={requestOf({ id: 42, project_id: 7 })} />);

    expect(
      screen.getByRole("link", { name: text("projects.labels.duplicate") }),
    ).toHaveAttribute("href", "/requests/new?project_id=7&request_id=42");
  });

  it("project_id が変われば、移動先も変わります", () => {
    render(<RequestRow request={requestOf({ id: 99, project_id: 3 })} />);

    expect(
      screen.getByRole("link", { name: text("projects.labels.duplicate") }),
    ).toHaveAttribute("href", "/requests/new?project_id=3&request_id=99");
  });
});
