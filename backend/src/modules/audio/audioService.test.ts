import { describe, expect, it } from "vitest";
import { looksLikeMp3, parseRange } from "./audioService";

describe("looksLikeMp3", () => {
  it.each([
    ["thẻ ID3 (ElevenLabs)", [0x49, 0x44, 0x33, 0x04, 0x00], true],
    ["khung MPEG trần", [0xff, 0xfb, 0x90, 0x64], true],
    ["PNG", [0x89, 0x50, 0x4e, 0x47], false],
    ["WAV", [0x52, 0x49, 0x46, 0x46], false],
    ["quá ngắn", [0x49, 0x44], false],
  ])("%s -> %s", (_, bytes, expected) => {
    expect(looksLikeMp3(Uint8Array.from(bytes))).toBe(expected);
  });
});

describe("parseRange", () => {
  it.each([
    [undefined, null],
    ["", null],
    ["items=0-1", null],
    ["bytes=-", null],
    ["bytes=0-1", { start: 0, end: 1 }],
    ["bytes=5-", { start: 5, end: 9 }],
    ["bytes=8-100", { start: 8, end: 9 }],
    ["bytes=-3", { start: 7, end: 9 }],
    ["bytes=-50", { start: 0, end: 9 }],
    ["bytes=10-", "unsatisfiable"],
    ["bytes=5-2", "unsatisfiable"],
    ["bytes=-0", "unsatisfiable"],
  ])("%j (file 10 byte) -> %j", (header, expected) => {
    expect(parseRange(header, 10)).toEqual(expected);
  });
});
