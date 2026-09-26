/**
 * Đầu vào từ vựng khi tạo bộ / thêm từ — đúng định dạng JSON mà prompt tách từ
 * trên claude.ai trả về, và cũng là định dạng của backend/prisma/seed-data/decks.json:
 *
 *   { "kr": "가다", "vi": "đi", "hint": "...", "altAnswers": ["..."],
 *     "followUp": { "kr": "...", "vi": "..." } }   // hoặc "followUps": [...]
 */
export interface FollowUpInput {
  kr?: string;
  vi: string;
  hint?: string | null;
}

export interface WordInput {
  kr: string;
  vi: string;
  hint?: string | null;
  altAnswers?: string[] | null;
  followUp?: FollowUpInput | null;
  followUps?: FollowUpInput[] | null;
}

/** Một thẻ sau khi làm phẳng. `parentOffset` là vị trí (trong cùng lô) của
 * thẻ gốc nếu đây là thẻ ngữ cảnh. */
export interface ExpandedCard {
  kr: string;
  vi: string;
  hint: string | null;
  altAnswers: string[];
  parentOffset: number | null;
}

/**
 * Làm phẳng chuỗi thẻ ngữ cảnh: thẻ gốc rồi tới các thẻ ngữ cảnh theo thứ tự;
 * `followUps` được ưu tiên hơn `followUp`; thẻ ngữ cảnh thiếu `kr` thì mượn
 * `kr` của thẻ gốc. `scripts/importContent.ts` dựng id bộ gốc ("ds2-7") từ vị
 * trí sau khi làm phẳng — đổi thứ tự ở đây là id lệch với DB đang có.
 */
export function expandWordInputs(words: WordInput[]): ExpandedCard[] {
  const out: ExpandedCard[] = [];
  for (const w of words) {
    const parentOffset = out.length;
    out.push({
      kr: w.kr.trim(),
      vi: w.vi.trim(),
      hint: cleanHint(w.hint),
      altAnswers: cleanAlts(w.altAnswers, w.kr),
      parentOffset: null,
    });
    const chain = w.followUps?.length ? w.followUps : w.followUp ? [w.followUp] : [];
    for (const fu of chain) {
      out.push({
        kr: (fu.kr ?? w.kr).trim(),
        vi: fu.vi.trim(),
        hint: cleanHint(fu.hint),
        altAnswers: [],
        parentOffset,
      });
    }
  }
  return out;
}

function cleanHint(hint: string | null | undefined): string | null {
  const h = hint?.trim();
  return h ? h : null;
}

/** Bỏ rỗng, bỏ trùng, bỏ đáp án phụ trùng đáp án chính — giống dialog sửa thẻ. */
export function cleanAlts(alts: string[] | null | undefined, kr: string): string[] {
  const main = kr.trim();
  return [...new Set((alts ?? []).map((a) => a.trim()).filter((a) => a && a !== main))];
}

export type ParseResult<T> = { ok: true; value: T } | { ok: false; error: string };

const MAX_WORDS = 500;

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function nonEmptyString(v: unknown): v is string {
  return typeof v === "string" && v.trim().length > 0;
}

function optionalString(v: unknown): boolean {
  return v === undefined || v === null || typeof v === "string";
}

function checkFollowUp(v: unknown, path: string): string | null {
  if (!isRecord(v)) return `${path}: phải là object`;
  if (v.kr !== undefined && !nonEmptyString(v.kr)) return `${path}.kr: phải là chuỗi không rỗng`;
  if (!nonEmptyString(v.vi)) return `${path}.vi: thiếu nghĩa tiếng Việt`;
  if (!optionalString(v.hint)) return `${path}.hint: phải là chuỗi`;
  return null;
}

/** Kiểm tra mảng từ gửi lên; thông báo lỗi chỉ rõ từ thứ mấy để người dùng sửa JSON. */
export function parseWordInputs(input: unknown): ParseResult<WordInput[]> {
  if (!Array.isArray(input)) return { ok: false, error: "words phải là mảng" };
  if (input.length === 0) return { ok: false, error: "words đang trống" };
  if (input.length > MAX_WORDS) return { ok: false, error: `tối đa ${MAX_WORDS} từ mỗi lần` };

  for (let i = 0; i < input.length; i++) {
    const w: unknown = input[i];
    const path = `words[${i}]`;
    if (!isRecord(w)) return { ok: false, error: `${path}: phải là object` };
    if (!nonEmptyString(w.kr)) return { ok: false, error: `${path}.kr: thiếu từ tiếng Hàn` };
    if (!nonEmptyString(w.vi)) return { ok: false, error: `${path}.vi: thiếu nghĩa tiếng Việt` };
    if (!optionalString(w.hint)) return { ok: false, error: `${path}.hint: phải là chuỗi` };
    if (
      w.altAnswers !== undefined &&
      w.altAnswers !== null &&
      !(Array.isArray(w.altAnswers) && w.altAnswers.every((a) => typeof a === "string"))
    ) {
      return { ok: false, error: `${path}.altAnswers: phải là mảng chuỗi` };
    }
    if (w.followUp !== undefined && w.followUp !== null) {
      const err = checkFollowUp(w.followUp, `${path}.followUp`);
      if (err) return { ok: false, error: err };
    }
    if (w.followUps !== undefined && w.followUps !== null) {
      if (!Array.isArray(w.followUps))
        return { ok: false, error: `${path}.followUps: phải là mảng` };
      for (let j = 0; j < w.followUps.length; j++) {
        const err = checkFollowUp(w.followUps[j], `${path}.followUps[${j}]`);
        if (err) return { ok: false, error: err };
      }
    }
  }
  return { ok: true, value: input as WordInput[] };
}
