/**
 * Đầu vào từ vựng khi tạo bộ / thêm từ — đúng định dạng JSON mà prompt tách từ
 * trên claude.ai trả về:
 *
 *   { "front": "đi", "back": "가다", "hint": "...", "altAnswers": ["..."],
 *     "typeAnswer": true,                            // không bắt buộc
 *     "note": "**Markdown** giải thích đáp án" }     // không bắt buộc
 *
 * `front` là mặt hiện ra (câu hỏi), `back` là đáp án.
 */
export interface WordInput {
  back: string;
  front: string;
  hint?: string | null;
  note?: string | null;
  altAnswers?: string[] | null;
  typeAnswer?: boolean | null;
}

/** Một thẻ đã dọn sạch, sẵn sàng ghi vào DB. */
export interface CleanCard {
  back: string;
  front: string;
  hint: string | null;
  note: string | null;
  altAnswers: string[];
  typeAnswer: boolean;
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

/** Dọn từng từ: trim, bỏ đáp án phụ thừa, `typeAnswer` mặc định theo độ dài. */
export function cleanWordInputs(words: WordInput[]): CleanCard[] {
  return words.map((w) => {
    const back = w.back.trim();
    return {
      back,
      front: w.front.trim(),
      hint: cleanHint(w.hint),
      note: cleanNote(w.note),
      altAnswers: cleanAlts(w.altAnswers, back),
      typeAnswer: w.typeAnswer ?? defaultTypeAnswer(back),
    };
  });
}

function cleanHint(hint: string | null | undefined): string | null {
  const h = hint?.trim();
  return h ? h : null;
}

/**
 * Giải thích là Markdown dán từ AI: thụt lề / dòng trống ở giữa là định dạng
 * (danh sách lồng, khối code) nên giữ nguyên — không `trim()` như gợi ý. Chỉ
 * đổi CRLF -> LF, bỏ dòng trống ở đầu và khoảng trắng ở cuối.
 */
export function cleanNote(note: string | null | undefined): string | null {
  if (!note?.trim()) return null;
  return note
    .replace(/\r\n?/g, "\n")
    .replace(/^(?:[ \t]*\n)+/, "")
    .trimEnd();
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
    if (!optionalString(w.note)) return { ok: false, error: `${path}.note: phải là chuỗi` };
    if (!optionalBoolean(w.typeAnswer))
      return { ok: false, error: `${path}.typeAnswer: phải là true/false` };
    if (
      w.altAnswers !== undefined &&
      w.altAnswers !== null &&
      !(Array.isArray(w.altAnswers) && w.altAnswers.every((a) => typeof a === "string"))
    ) {
      return { ok: false, error: `${path}.altAnswers: phải là mảng chuỗi` };
    }
    // Thẻ ngữ cảnh đã bỏ: báo lỗi thay vì lặng lẽ vứt mất phần JSON đó.
    if (w.followUp != null || w.followUps != null) {
      return {
        ok: false,
        error: `${path}: không còn hỗ trợ followUp/followUps — tách thành từ riêng`,
      };
    }
  }
  return { ok: true, value: input as WordInput[] };
}
