import { describe, expect, it } from "vitest";
import { cleanNote, cleanWordInputs, defaultTypeAnswer, parseWordInputs } from "./wordInput";

describe("cleanWordInputs — phải giống hệt cleanWords bên Dart", () => {
  it("giữ thứ tự, trim mặt trước/sau/gợi ý", () => {
    const out = cleanWordInputs([
      { back: " 가다 ", front: " đi ", hint: "  " },
      { back: "학생", front: "học sinh", hint: " hs " },
    ]);
    expect(out.map((c) => [c.back, c.front, c.hint])).toEqual([
      ["가다", "đi", null],
      ["학생", "học sinh", "hs"],
    ]);
  });

  it("dọn đáp án phụ: bỏ rỗng, bỏ trùng, bỏ trùng đáp án chính", () => {
    const [c] = cleanWordInputs([
      { back: "학생", front: "hs", altAnswers: ["학생", "", "생도", "생도"] },
    ]);
    expect(c!.altAnswers).toEqual(["생도"]);
  });

  it("không ghi typeAnswer: mặt sau ≤ 3 từ là gõ đáp án, dài hơn là tự chấm", () => {
    const out = cleanWordInputs([
      { back: "간 이식 수술", front: "ghép gan" },
      { back: "간 이식 수술을 하다", front: "làm phẫu thuật ghép gan" },
    ]);
    expect(out.map((c) => c.typeAnswer)).toEqual([true, false]);
  });

  it("ghi rõ typeAnswer thì luôn theo đó", () => {
    const out = cleanWordInputs([
      { back: "가다", front: "đi", typeAnswer: false },
      { back: "학교에 가서 공부를 하다", front: "đi học", typeAnswer: true },
    ]);
    expect(out.map((c) => c.typeAnswer)).toEqual([false, true]);
  });
});

describe("defaultTypeAnswer", () => {
  it.each([
    ["가다", true],
    ["  학교에   가다  ", true],
    ["1일 2회 복용", true],
    ["1일 2회, 1회 1정 복용", false],
  ])("%j -> %s", (back, expected) => {
    expect(defaultTypeAnswer(back)).toBe(expected);
  });
});

describe("cleanNote — giữ nguyên Markdown dán từ AI", () => {
  it("giữ thụt lề và dòng trống ở giữa; bỏ dòng trống hai đầu, đổi CRLF", () => {
    const md = "\r\n\r\n## Cách dùng\r\n\r\n- **가다**: đi\r\n  - lồng\r\n\r\n    code\r\n  \n";
    expect(cleanNote(md)).toBe("## Cách dùng\n\n- **가다**: đi\n  - lồng\n\n    code");
  });

  it("dòng đầu thụt lề (khối code) không bị trim", () => {
    expect(cleanNote("    x = 1\n")).toBe("    x = 1");
  });

  it.each([[null], [undefined], [""], ["  \n\t "]])("%j -> null", (v) => {
    expect(cleanNote(v)).toBeNull();
  });

  it("nhập bộ: note theo từng thẻ", () => {
    const out = cleanWordInputs([
      { back: "가다", front: "đi", note: "gốc" },
      { back: "오다", front: "đến", note: "\nthứ hai" },
    ]);
    expect(out.map((c) => c.note)).toEqual(["gốc", "thứ hai"]);
  });
});

describe("parseWordInputs", () => {
  it("chấp nhận đúng định dạng prompt tách từ trả về", () => {
    const r = parseWordInputs([
      { back: "치아", front: "răng", hint: "xỉ nha" },
      { back: "눈", front: "mắt", typeAnswer: false, note: "**giải thích**" },
    ]);
    expect(r.ok).toBe(true);
  });

  it.each([
    [[], "trống"],
    ["không phải mảng", "mảng"],
    [[{ front: "thiếu back" }], "words[0].back"],
    [[{ back: "x" }], "words[0].front"],
    [[{ back: "x", front: "y", altAnswers: [1] }], "altAnswers"],
    [[{ back: "x", front: "y", typeAnswer: "có" }], "words[0].typeAnswer"],
    [[{ back: "x", front: "y", note: 1 }], "words[0].note"],
    [[{ back: "x", front: "y", followUp: { front: "z" } }], "words[0]: không còn hỗ trợ followUp"],
    [[{ back: "x", front: "y", followUps: [] }], "words[0]: không còn hỗ trợ followUp"],
    [[{ kr: "x", vi: "y" }], "words[0].front"],
  ])("từ chối %j — báo đúng chỗ sai", (input, expected) => {
    const r = parseWordInputs(input);
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toContain(expected);
  });
});
