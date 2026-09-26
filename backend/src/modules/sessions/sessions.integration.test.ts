import { describe, expect, it } from "vitest";
import { call, useTestServer } from "../../testing/testServer";

/** Chạy trên Postgres dev thật (docker compose up -d), user test riêng. */
const server = useTestServer();
const api = (method: string, path: string, body?: unknown) =>
  call(server.baseUrl, method, path, body);

async function makeDeckId() {
  const g = await api("POST", "/groups", { name: "G" });
  const d = await api("POST", "/decks", {
    groupId: g.json.id,
    name: "D",
    words: [{ back: "가", front: "a" }],
  });
  return d.json.id as string;
}

function session(deckId: string, over: Record<string, unknown> = {}) {
  return {
    id: "3f6c2a9e-0000-4000-8000-000000000001",
    deckId,
    device: "ios",
    startedAt: "2026-09-20T10:00:00Z",
    endedAt: "2026-09-20T10:12:00Z",
    attempted: 30,
    correct: 26,
    masteredCount: 20,
    totalCards: 20,
    completed: true,
    ...over,
  };
}

describe("lịch sử các lần học", () => {
  it("gửi lại cùng một lần học (hàng đợi offline gửi 2 lần) chỉ lưu một bản ghi", async () => {
    const deckId = await makeDeckId();
    const first = await api("POST", "/sessions", { sessions: [session(deckId)] });
    const again = await api("POST", "/sessions", { sessions: [session(deckId)] });
    expect(first.json.inserted).toBe(1);
    expect(again.json.inserted).toBe(0);
    expect((await api("GET", "/sessions")).json.sessions).toHaveLength(1);
  });

  it("hai máy học cùng bộ cùng lúc -> hai bản ghi, không đè nhau", async () => {
    const deckId = await makeDeckId();
    await api("POST", "/sessions", {
      sessions: [
        session(deckId, { id: "aaaaaaaa-0000-4000-8000-000000000001", device: "ios" }),
        session(deckId, { id: "bbbbbbbb-0000-4000-8000-000000000002", device: "macos" }),
      ],
    });
    const all = (await api("GET", "/sessions")).json.sessions;
    expect(all.map((s: any) => s.device).sort()).toEqual(["ios", "macos"]);
  });

  it("lần học của bộ đã bị xoá thì bỏ qua, không làm hỏng cả lô", async () => {
    const deckId = await makeDeckId();
    const r = await api("POST", "/sessions", {
      sessions: [
        session(deckId),
        session("bo-da-xoa", { id: "cccccccc-0000-4000-8000-000000000003" }),
      ],
    });
    expect(r.status).toBe(200);
    expect(r.json).toMatchObject({ received: 2, inserted: 1, unknownDeck: 1 });
  });

  it.each([
    [{ correct: 99 }, "correct"],
    [{ endedAt: "2026-09-20T09:00:00Z" }, "endedAt"],
    [{ completed: "yes" }, "completed"],
    [{ id: "ngan" }, "id"],
  ])("từ chối dữ liệu sai %j", async (over, expected) => {
    const deckId = await makeDeckId();
    const r = await api("POST", "/sessions", { sessions: [session(deckId, over)] });
    expect(r.status).toBe(400);
    expect(r.json.error).toContain(expected);
  });
});
