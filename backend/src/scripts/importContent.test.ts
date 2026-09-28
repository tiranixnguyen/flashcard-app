import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { buildImportPlan } from "./importContent";

/**
 * Chạy trên DỮ LIỆU THẬT: 28 bộ gốc + chỉnh sửa/đánh dấu thật của người dùng
 * (bản seed, giống hệt SyncState trên server lúc chuyển đổi). Sai ở đây là mất
 * chú thích hoặc áp nhầm thẻ.
 */
const decksJson = JSON.parse(
  readFileSync(join(__dirname, "../../prisma/seed-data/decks.json"), "utf-8"),
);
const legacy = JSON.parse(
  readFileSync(join(__dirname, "../../prisma/seed-data/vocab-state.json"), "utf-8"),
);
const plan = buildImportPlan(decksJson, legacy);
const card = (id: string) => plan.cards.find((c) => c.id === id);

describe("buildImportPlan trên dữ liệu thật", () => {
  it("đủ nhóm và bộ, giữ đúng id cũ", () => {
    expect(plan.groups.map((g) => [g.id, g.name])).toEqual([
      ["g1", "Sep1"],
      ["g2", "Sep2"],
      ["g3", "Sep3"],
    ]);
    expect(plan.decks).toHaveLength(28);
    expect(plan.decks[0]!.id).toBe("ds1");
  });

  it("586 thẻ sau khi làm phẳng, trừ 43 thẻ đã xoá = 543", () => {
    expect(plan.report.deleted).toBe(43);
    expect(plan.cards).toHaveLength(586 - 43);
  });

  it("áp đủ 32 chỉnh sửa, 17 ⭐, 5 漢, không bỏ qua entry nào", () => {
    expect(plan.report).toMatchObject({ edited: 32, marked: 17, hanja: 5, skipped: [] });
  });

  it("chỉnh sửa rơi đúng thẻ (so với vị trí đã làm phẳng, có tính thẻ ngữ cảnh)", () => {
    // ds2 có 3 thẻ ngữ cảnh chen giữa — nếu làm phẳng lệch, 키우다 sẽ không ở vị trí 16.
    expect(card("ds2-16")).toMatchObject({ back: "키우다", marked: true });
    expect(card("ds2-7")).toMatchObject({ back: "유치원", hint: "ấu: 유, trĩ: 치", hanja: true });
    expect(card("ds20-0")).toMatchObject({ back: "1일 2회, 1회 1정 복용", typeAnswer: false });
    expect(card("ds23-24")?.altAnswers).toEqual(["다양"]);
  });

  it("định dạng cũ kr/vi được chuyển thành back/front; đáp án ngắn thì gõ đáp án", () => {
    expect(card("ds1-0")).toMatchObject({ back: "치아", front: "răng", typeAnswer: true });
  });

  it("thẻ đã xoá không được tạo", () => {
    expect(card("ds3-4")).toBeUndefined(); // 자다
    expect(card("ds30-2")).toBeUndefined(); // 간
  });

  it("thẻ ngữ cảnh cũ thành thẻ thường ngay sau thẻ gốc", () => {
    expect(card("ds2-9")).toMatchObject({ back: "우리 아이", position: 9 });
    expect(card("ds2-9")).not.toHaveProperty("parentId");
  });

  it("entry lệch vị trí (baseKr khác) bị bỏ qua, không áp nhầm", () => {
    const p = buildImportPlan(decksJson, {
      marked: [{ deckId: "ds1", index: 0, baseKr: "không còn ở đây" }],
    });
    expect(p.cards.find((c) => c.id === "ds1-0")!.marked).toBe(false);
    expect(p.report.skipped).toHaveLength(1);
  });
});
