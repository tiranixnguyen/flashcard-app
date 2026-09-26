import { describe, expect, it } from "vitest";
import { expandWordInputs, parseWordInputs } from "./wordInput";

describe("expandWordInputs — phải giống hệt expandWords bên Dart", () => {
  it("thẻ ngữ cảnh nằm ngay sau thẻ gốc và trỏ về nó", () => {
    const out = expandWordInputs([
      { kr: "가다", vi: "đi", followUp: { kr: "학교에 가다", vi: "đi đến trường" } },
      { kr: "학생", vi: "học sinh" },
    ]);
    expect(out.map((c) => [c.kr, c.parentOffset])).toEqual([
      ["가다", null],
      ["학교에 가다", 0],
      ["학생", null],
    ]);
  });

  it("thẻ ngữ cảnh thiếu kr thì mượn kr của thẻ gốc", () => {
    const out = expandWordInputs([{ kr: "먹다", vi: "ăn", followUp: { vi: "ăn cơm" } }]);
    expect(out[1]!.kr).toBe("먹다");
  });

  it("followUps được ưu tiên hơn followUp", () => {
    const out = expandWordInputs([
      {
        kr: "a",
        vi: "a",
        followUp: { vi: "bị bỏ qua" },
        followUps: [{ vi: "một" }, { vi: "hai" }],
      },
    ]);
    expect(out.map((c) => c.vi)).toEqual(["a", "một", "hai"]);
    expect(out[2]!.parentOffset).toBe(0);
  });

  it("dọn đáp án phụ: bỏ rỗng, bỏ trùng, bỏ trùng đáp án chính", () => {
    const [c] = expandWordInputs([
      { kr: "학생", vi: "hs", altAnswers: ["학생", "", "생도", "생도"] },
    ]);
    expect(c!.altAnswers).toEqual(["생도"]);
  });
});

describe("parseWordInputs", () => {
  it("chấp nhận đúng định dạng prompt tách từ trả về", () => {
    const r = parseWordInputs([
      { kr: "치아", vi: "răng", hint: "xỉ nha" },
      { kr: "눈", vi: "mắt" },
    ]);
    expect(r.ok).toBe(true);
  });

  it.each([
    [[], "trống"],
    ["không phải mảng", "mảng"],
    [[{ vi: "thiếu kr" }], "words[0].kr"],
    [[{ kr: "x" }], "words[0].vi"],
    [[{ kr: "x", vi: "y", altAnswers: [1] }], "altAnswers"],
    [[{ kr: "x", vi: "y", followUp: { kr: "z" } }], "followUp.vi"],
  ])("từ chối %j — báo đúng chỗ sai", (input, expected) => {
    const r = parseWordInputs(input);
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toContain(expected);
  });
});
