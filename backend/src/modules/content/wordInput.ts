/**
 * Đầu vào từ vựng khi tạo bộ / thêm từ — đúng định dạng JSON mà prompt tách từ
 * trên claude.ai trả về:
 *
 *   { "front": "đi", "back": "가다", "hint": "...", "altAnswers": ["..."],
 *     "typeAnswer": true,                            // không bắt buộc
 *     "followUp": { "front": "...", "back": "..." } } // hoặc "followUps": [...]
 *
 * `front` là mặt hiện ra (câu hỏi), `back` là đáp án.
 */
export interface FollowUpInput {
  back?: string;
  front: string;
  hint?: string | null;
  typeAnswer?: boolean | null;
}

export interface WordInput {
  back: string;
  front: string;
  hint?: string | null;
  altAnswers?: string[] | null;
  typeAnswer?: boolean | null;
  followUp?: FollowUpInput | null;
  followUps?: FollowUpInput[] | null;
}

/** Một thẻ sau khi làm phẳng. `parentOffset` là vị trí (trong cùng lô) của
 * thẻ gốc nếu đây là thẻ ngữ cảnh. */
export interface ExpandedCard {
  back: string;
  front: string;
  hint: string | null;
  altAnswers: string[];
  typeAnswer: boolean;
  parentOffset: number | null;
}

/** Mặt sau tối đa bấy nhiêu từ thì coi là "ngắn". */
export const SHORT_ANSWER_MAX_WORDS = 3;

/**
 * Nhập bộ mà không ghi rõ `typeAnswer`: đáp án ngắn (≤ 3 từ) thì gõ đáp án,
 * dài hơn (câu, cụm dài — gõ lại từng chữ rất mệt) thì là thẻ tự chấm. Phải
 * giống `defaultTypeAnswer` bên Dart và câu UPDATE trong migration
 * card_front_back_type_answer.
 */
export function defaultTypeAnswer(back: string): boolean {
  return back.trim().split(/\s+/).length <= SHORT_ANSWER_MAX_WORDS;
}

/**
 * Làm phẳng chuỗi thẻ ngữ cảnh: thẻ gốc rồi tới các thẻ ngữ cảnh theo thứ tự;
 * `followUps` được ưu tiên hơn `followUp`; thẻ ngữ cảnh thiếu `back` thì mượn
 * `back` của thẻ gốc. `scripts/importContent.ts` dựng id bộ gốc ("ds2-7") từ
 * vị trí sau khi làm phẳng — đổi thứ tự ở đây là id lệch với DB đang có.
 */
export function expandWordInputs(words: WordInput[]): ExpandedCard[] {
  const out: ExpandedCard[] = [];
  for (const w of words) {
    const parentOffset = out.length;
    const back = w.back.trim();
    out.push({
      back,
      front: w.front.trim(),
      hint: cleanHint(w.hint),
      altAnswers: cleanAlts(w.altAnswers, back),
      typeAnswer: w.typeAnswer ?? defaultTypeAnswer(back),
      parentOffset: null,
    });
    const chain = w.followUps?.length ? w.followUps : w.followUp ? [w.followUp] : [];
    for (const fu of chain) {
      const fuBack = (fu.back ?? w.back).trim();
      out.push({
        back: fuBack,
        front: fu.front.trim(),
        hint: cleanHint(fu.hint),
        altAnswers: [],
        typeAnswer: fu.typeAnswer ?? defaultTypeAnswer(fuBack),
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
export function cleanAlts(alts: string[] | null | undefined, back: string): string[] {
  const main = back.trim();
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

function optionalBoolean(v: unknown): boolean {
  return v === undefined || v === null || typeof v === "boolean";
}

function checkFollowUp(v: unknown, path: string): string | null {
  if (!isRecord(v)) return `${path}: phải là object`;
  if (v.back !== undefined && !nonEmptyString(v.back))
    return `${path}.back: phải là chuỗi không rỗng`;
  if (!nonEmptyString(v.front)) return `${path}.front: thiếu mặt trước`;
  if (!optionalString(v.hint)) return `${path}.hint: phải là chuỗi`;
  if (!optionalBoolean(v.typeAnswer)) return `${path}.typeAnswer: phải là true/false`;
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
    if (!nonEmptyString(w.front)) return { ok: false, error: `${path}.front: thiếu mặt trước` };
    if (!nonEmptyString(w.back)) return { ok: false, error: `${path}.back: thiếu mặt sau` };
    if (!optionalString(w.hint)) return { ok: false, error: `${path}.hint: phải là chuỗi` };
    if (!optionalBoolean(w.typeAnswer))
      return { ok: false, error: `${path}.typeAnswer: phải là true/false` };
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
