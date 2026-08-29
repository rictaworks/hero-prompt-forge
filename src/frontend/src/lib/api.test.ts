import { apiGet, apiPatch, apiPost } from "@/lib/api";

/**
 * バックエンドへの呼び出しです。
 *
 * **セッションのクッキーを必ず送ります。** 認証はクッキーによります。
 * `credentials` を `include` へ変えると、別の生成元へもクッキーが漏れます
 * （PR #182 のレビューより）。
 */
describe("バックエンドへの呼び出し", () => {
  function okResponse(body: unknown = null) {
    return {
      ok: true,
      status: 200,
      text: () => Promise.resolve(body === null ? "" : JSON.stringify(body)),
    } as Response;
  }

  beforeEach(() => {
    global.fetch = jest.fn().mockResolvedValue(okResponse({ ok: true }));
  });

  it("GET は同一生成元のクッキーだけを送ります", async () => {
    await apiGet("/projects");

    expect(global.fetch).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({ credentials: "same-origin" }),
    );
  });

  it("POST も同一生成元のクッキーだけを送ります", async () => {
    await apiPost("/prompt_requests", { body: { project_id: 1 } });

    expect(global.fetch).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({ credentials: "same-origin" }),
    );
  });

  it("PATCH も同一生成元のクッキーだけを送ります", async () => {
    await apiPatch("/prompt_requests/1", { body: {} });

    expect(global.fetch).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({ credentials: "same-origin" }),
    );
  });

  it("他の生成元へクッキーを送りません（include ではありません）", async () => {
    await apiGet("/projects");

    expect(global.fetch).not.toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({ credentials: "include" }),
    );
  });
});
