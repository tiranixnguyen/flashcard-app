import { describe, expect, it } from "vitest";
import { call, useTestServer } from "../../testing/testServer";

/** Chạy trên Postgres dev thật (docker compose up -d), user test riêng. */
const server = useTestServer();
const api = (method: string, path: string, body?: unknown) =>
  call(server.baseUrl, method, path, body);

async function makeGroup(name = "Tháng 10") {
  const r = await api("POST", "/groups", { name });
  expect(r.status).toBe(201);
  return r.json as { id: string; name: string; position: number };
}

async function makeDeck(groupId: string, words: unknown[]) {
  const r = await api("POST", "/decks", { groupId, name: "Bài 1", words });
  expect(r.status).toBe(201);
  return r.json as { id: string; cards: any[] };
}

describe("nhóm", () => {
  it("tạo nhóm mới xếp cuối, đổi tên được", async () => {
    const a = await makeGroup("A");
    const b = await makeGroup("B");
    expect([a.position, b.position]).toEqual([0, 1]);

    const renamed = await api("PATCH", `/groups/${a.id}`, { name: "  Sep4  " });
    expect(renamed.json.name).toBe("Sep4");

    const content = await api("GET", "/content");
    expect(content.json.groups.map((g: any) => g.name)).toEqual(["Sep4", "B"]);
  });

  it("tên rỗng -> 400; nhóm không tồn tại -> 404", async () => {
    expect((await api("POST", "/groups", { name: "   " })).status).toBe(400);
    expect((await api("PATCH", "/groups/khong-co", { name: "x" })).status).toBe(404);
  });
});

describe("bộ từ và thẻ", () => {
  it("tạo bộ từ JSON của prompt tách từ, làm phẳng thẻ ngữ cảnh", async () => {
    const g = await makeGroup();
    const deck = await makeDeck(g.id, [
      { back: "가다", front: "đi", followUp: { back: "학교에 가다", front: "đi đến trường" } },
      { back: "공지하다", front: "thông báo", hint: "công tri", altAnswers: ["공지"] },
    ]);
    expect(deck.cards.map((c) => [c.position, c.back])).toEqual([
      [0, "가다"],
      [1, "학교에 가다"],
      [2, "공지하다"],
    ]);
    expect(deck.cards[1].parentId).toBe(deck.cards[0].id);
    expect(deck.cards[2]).toMatchObject({ hint: "công tri", altAnswers: ["공지"] });
  });

  it("JSON sai định dạng -> 400 kèm vị trí từ sai; nhóm không tồn tại -> 404", async () => {
    const g = await makeGroup();
    const bad = await api("POST", "/decks", { groupId: g.id, name: "x", words: [{ back: "a" }] });
    expect(bad.status).toBe(400);
    expect(bad.json.error).toContain("words[0].front");

    const noGroup = await api("POST", "/decks", {
      groupId: "khong-co",
      name: "x",
      words: [{ back: "a", front: "b" }],
    });
    expect(noGroup.status).toBe(404);
  });

  it("bộ tối đa 500 từ, mỗi từ 2 thẻ ngữ cảnh -> tạo trọn trong một transaction", async () => {
    const g = await makeGroup();
    const words = Array.from({ length: 500 }, (_, i) => ({
      back: `단어${i}`,
      front: `từ ${i}`,
      followUps: [{ front: `ngữ cảnh ${i}a` }, { front: `ngữ cảnh ${i}b` }],
    }));
    const deck = await makeDeck(g.id, words);
    expect(deck.cards).toHaveLength(1500);
    expect(deck.cards.map((c) => c.position)).toEqual([...Array(1500).keys()]);
    // Thẻ ngữ cảnh trỏ đúng thẻ gốc đứng ngay trước nó trong cùng lô.
    expect(deck.cards[1499].parentId).toBe(deck.cards[1497].id);
    expect(deck.cards[1499].back).toBe("단어499");
  });

  it("thêm từ vào CUỐI bộ, thứ tự cũ giữ nguyên", async () => {
    const g = await makeGroup();
    const deck = await makeDeck(g.id, [{ back: "하나", front: "một" }]);
    const r = await api("POST", `/decks/${deck.id}/cards`, {
      words: [
        { back: "둘", front: "hai" },
        { back: "셋", front: "ba" },
      ],
    });
    expect(r.json.cards.map((c: any) => [c.position, c.back])).toEqual([
      [0, "하나"],
      [1, "둘"],
      [2, "셋"],
    ]);
  });

  it("sửa thẻ ghi thẳng lên server; xoá thẻ gốc xoá luôn thẻ ngữ cảnh", async () => {
    const g = await makeGroup();
    const deck = await makeDeck(g.id, [
      { back: "가다", front: "đi", followUp: { front: "đi đến trường" } },
      { back: "오다", front: "đến" },
    ]);
    const [root, , other] = deck.cards;

    const edited = await api("PATCH", `/cards/${other.id}`, {
      back: "오다",
      front: "đến, tới",
      hint: "  ",
      altAnswers: ["오다", "와요"],
    });
    expect(edited.json).toMatchObject({ front: "đến, tới", hint: null, altAnswers: ["와요"] });

    expect((await api("DELETE", `/cards/${root.id}`)).status).toBe(204);
    const content = await api("GET", "/content");
    expect(content.json.decks[0].cards.map((c: any) => c.back)).toEqual(["오다"]);
  });

  it("kiểu thẻ: nhập bộ tự chọn theo độ dài mặt sau; PATCH đổi được, bỏ trống thì giữ", async () => {
    const g = await makeGroup();
    const deck = await makeDeck(g.id, [
      { back: "가다", front: "đi" },
      { back: "쓰레기는 줄이고 재활용은 늘리다", front: "giảm rác, tăng tái chế" },
      { back: "오다", front: "đến", typeAnswer: false },
    ]);
    expect(deck.cards.map((c) => c.typeAnswer)).toEqual([true, false, false]);

    const id = deck.cards[0].id;
    const off = await api("PATCH", `/cards/${id}`, {
      back: "가다",
      front: "đi",
      typeAnswer: false,
    });
    expect(off.json.typeAnswer).toBe(false);
    const kept = await api("PATCH", `/cards/${id}`, { back: "가다", front: "đi (sửa)" });
    expect(kept.json).toMatchObject({ front: "đi (sửa)", typeAnswer: false });

    const bad = await api("PATCH", `/cards/${id}`, { back: "가다", front: "đi", typeAnswer: 1 });
    expect(bad.status).toBe(400);
  });

  it("giải thích: nhập bộ giữ nguyên Markdown; PATCH bỏ trống thì giữ, rỗng thì xoá", async () => {
    const g = await makeGroup();
    const md = "## Vì sao\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n- ý 1\n  - ý lồng";
    const deck = await makeDeck(g.id, [{ back: "가다", front: "đi", note: `\n${md}\n\n` }]);
    const id = deck.cards[0].id;
    expect(deck.cards[0].note).toBe(md);

    const kept = await api("PATCH", `/cards/${id}`, { back: "가다", front: "đi (sửa)" });
    expect(kept.json.note).toBe(md);
    const changed = await api("PATCH", `/cards/${id}`, { back: "가다", front: "đi", note: "mới" });
    expect(changed.json.note).toBe("mới");
    const cleared = await api("PATCH", `/cards/${id}`, { back: "가다", front: "đi", note: "  " });
    expect(cleared.json.note).toBeNull();

    const bad = await api("PATCH", `/cards/${id}`, { back: "가다", front: "đi", note: 1 });
    expect(bad.status).toBe(400);
  });

  it("thẻ không tồn tại -> 404", async () => {
    expect((await api("PATCH", "/cards/khong-co", { back: "a", front: "b" })).status).toBe(404);
    expect((await api("DELETE", "/cards/khong-co")).status).toBe(404);
  });
});

describe("dấu ⭐/漢 — lần bấm muộn nhất thắng, mỗi dấu tính riêng", () => {
  it("lần bấm cũ tới sau (hàng đợi offline) không đè lần bấm mới hơn", async () => {
    const g = await makeGroup();
    const { cards } = await makeDeck(g.id, [{ back: "가", front: "a" }]);
    const id = cards[0].id;

    await api("POST", "/cards/flags", {
      changes: [{ cardId: id, marked: true, changedAt: "2026-01-02T00:00:00Z" }],
    });
    const stale = await api("POST", "/cards/flags", {
      changes: [{ cardId: id, marked: false, changedAt: "2026-01-01T00:00:00Z" }],
    });
    expect(stale.json).toEqual({ applied: 0, ignored: 1 });

    const content = await api("GET", "/content");
    expect(content.json.decks[0].cards[0].marked).toBe(true);
  });

  it("đổi 漢 muộn hơn không làm lần đổi ⭐ sớm hơn bị từ chối", async () => {
    const g = await makeGroup();
    const { cards } = await makeDeck(g.id, [{ back: "가", front: "a" }]);
    const id = cards[0].id;

    await api("POST", "/cards/flags", {
      changes: [{ cardId: id, hanja: true, changedAt: "2026-01-05T00:00:00Z" }],
    });
    const r = await api("POST", "/cards/flags", {
      changes: [{ cardId: id, marked: true, changedAt: "2026-01-01T00:00:00Z" }],
    });
    expect(r.json.applied).toBe(1);
    const c = (await api("GET", "/content")).json.decks[0].cards[0];
    expect([c.marked, c.hanja]).toEqual([true, true]);
  });

  it("thẻ đã bị xoá thì bỏ qua, không lỗi", async () => {
    const r = await api("POST", "/cards/flags", {
      changes: [{ cardId: "da-xoa", marked: true, changedAt: "2026-01-01T00:00:00Z" }],
    });
    expect(r.status).toBe(200);
    expect(r.json).toEqual({ applied: 0, ignored: 1 });
  });
});
