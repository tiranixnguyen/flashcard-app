/**
 * Chuyển 28 bộ gốc (prisma/seed-data/decks.json) vào bảng Group/Deck/Card, áp
 * luôn chỉnh sửa + xoá thẻ + dấu ⭐/漢 thật của người dùng lấy từ snapshot đồng
 * bộ cũ (bảng SyncState; không có thì dùng prisma/seed-data/vocab-state.json).
 * Tiến trình theo từng thẻ (box/streak/mastered) cố ý bỏ — đã thay bằng lịch
 * sử các lần học.
 *
 * Chạy (từ thư mục backend/):  npm run import-content
 * Chỉ chạy được khi user CHƯA có nhóm nào — không bao giờ ghi đè nội dung đã có.
 *
 * Id giữ ổn định để khớp bản đóng gói trong app khi máy chưa từng có mạng:
 * nhóm "g1".."g3", bộ "ds1".."ds30", thẻ "<deckId>-<vị trí sau khi làm phẳng>".
 * Định dạng cũ còn thẻ ngữ cảnh (followUp) — giờ chúng thành thẻ thường nằm
 * ngay sau thẻ gốc, nhưng vẫn phải đếm vào vị trí để id khớp DB đang có.
 */
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { prisma } from "../config/db";
import { ensureDefaultUser } from "../modules/common/defaultUser";
import {
  cleanWordInputs,
  defaultTypeAnswer,
  type WordInput,
} from "../modules/content/wordInput";

/** Định dạng cũ của seed-data/decks.json: `kr` là đáp án, `vi` là câu hỏi. */
interface LegacyFollowUp {
  kr?: string;
  vi: string;
  hint?: string | null;
}
interface LegacyWord {
  kr: string;
  vi: string;
  hint?: string | null;
  altAnswers?: string[] | null;
  followUp?: LegacyFollowUp | null;
  followUps?: LegacyFollowUp[] | null;
}

interface DecksJson {
  vocabGroups: { id: string; name: string }[];
  decks: { id: string; name: string; group?: string; category?: string; words: LegacyWord[] }[];
}

/** Một thẻ sau khi làm phẳng; `parentOffset` là vị trí thẻ gốc nếu đây là thẻ
 * ngữ cảnh cũ — chỉ để xoá theo khi thẻ gốc đã bị xoá (giống app cũ). */
type LegacyCard = WordInput & { parentOffset: number | null };

/**
 * kr/vi -> back/front, làm phẳng chuỗi thẻ ngữ cảnh: thẻ gốc rồi tới các thẻ
 * ngữ cảnh theo thứ tự; `followUps` được ưu tiên hơn `followUp`; thẻ ngữ cảnh
 * thiếu `kr` thì mượn của thẻ gốc. `typeAnswer` để trống cho quy tắc mặc định.
 * Đổi thứ tự ở đây là id lệch với DB đang có.
 */
export function flattenLegacyWords(words: LegacyWord[]): LegacyCard[] {
  const out: LegacyCard[] = [];
  for (const w of words) {
    const parentOffset = out.length;
    out.push({
      front: w.vi,
      back: w.kr,
      hint: w.hint ?? null,
      altAnswers: w.altAnswers ?? null,
      parentOffset: null,
    });
    const chain = w.followUps?.length ? w.followUps : w.followUp ? [w.followUp] : [];
    for (const f of chain) {
      out.push({ front: f.vi, back: f.kr ?? w.kr, hint: f.hint ?? null, parentOffset });
    }
  }
  return out;
}

interface LegacyEntry {
  deckId: string;
  index: number;
  baseKr: string;
}
interface LegacyOverlay extends LegacyEntry {
  vi: string;
  kr: string;
  hint: string | null;
  altAnswers: string[] | null;
  deleted: boolean;
}
interface LegacyState {
  overlay?: LegacyOverlay[];
  marked?: LegacyEntry[];
  hanja?: LegacyEntry[];
}

export interface ImportPlan {
  groups: { id: string; name: string; position: number }[];
  decks: { id: string; groupId: string; name: string; position: number }[];
  cards: {
    id: string;
    deckId: string;
    position: number;
    front: string;
    back: string;
    hint: string | null;
    altAnswers: string[];
    typeAnswer: boolean;
    marked: boolean;
    hanja: boolean;
  }[];
  report: { edited: number; deleted: number; marked: number; hanja: number; skipped: string[] };
}

/**
 * Thuần — không đụng DB — để test được. `baseKr` phải khớp từ gốc tại đúng vị
 * trí, lệch thì bỏ qua entry (giống quy tắc cũ bên app): áp nhầm thẻ còn tệ
 * hơn mất một chỉnh sửa.
 */
export function buildImportPlan(decksJson: DecksJson, legacy: LegacyState): ImportPlan {
  const report: ImportPlan["report"] = { edited: 0, deleted: 0, marked: 0, hanja: 0, skipped: [] };
  const key = (deckId: string, index: number) => `${deckId}#${index}`;

  const overlay = new Map((legacy.overlay ?? []).map((e) => [key(e.deckId, e.index), e]));
  const marked = new Map((legacy.marked ?? []).map((e) => [key(e.deckId, e.index), e]));
  const hanja = new Map((legacy.hanja ?? []).map((e) => [key(e.deckId, e.index), e]));

  const groups = decksJson.vocabGroups.map((g, i) => ({ id: g.id, name: g.name, position: i }));
  const firstGroup = groups[0]!.id;
  const deckPositionInGroup = new Map<string, number>();
  const decks: ImportPlan["decks"] = [];
  const cards: ImportPlan["cards"] = [];

  for (const d of decksJson.decks) {
    if ((d.category ?? "vocab") !== "vocab") continue;
    const groupId = d.group ?? firstGroup;
    const position = deckPositionInGroup.get(groupId) ?? 0;
    deckPositionInGroup.set(groupId, position + 1);
    decks.push({ id: d.id, groupId, name: d.name, position });

    const flat = flattenLegacyWords(d.words);
    const cleaned = cleanWordInputs(flat);
    const deletedIndexes = new Set<number>();
    cleaned.forEach((c, i) => {
      const k = key(d.id, i);
      const matches = (e: LegacyEntry | undefined) => {
        if (!e) return false;
        if (e.baseKr === c.back) return true;
        report.skipped.push(`${k}: baseKr "${e.baseKr}" ≠ "${c.back}"`);
        return false;
      };

      const parentOffset = flat[i]!.parentOffset;
      const parentGone = parentOffset !== null && deletedIndexes.has(parentOffset);
      const edit = overlay.get(k);
      if (parentGone || (matches(edit) && edit!.deleted)) {
        deletedIndexes.add(i);
        report.deleted++;
        return;
      }
      const isEdited = edit !== undefined && edit.baseKr === c.back;
      if (isEdited) report.edited++;
      const isMarked = matches(marked.get(k));
      const isHanja = matches(hanja.get(k));
      if (isMarked) report.marked++;
      if (isHanja) report.hanja++;

      cards.push({
        id: `${d.id}-${i}`,
        deckId: d.id,
        position: i,
        front: isEdited ? edit!.vi : c.front,
        back: isEdited ? edit!.kr : c.back,
        hint: isEdited ? edit!.hint : c.hint,
        altAnswers: isEdited ? (edit!.altAnswers ?? []) : c.altAnswers,
        typeAnswer: isEdited ? defaultTypeAnswer(edit!.kr) : c.typeAnswer,
        marked: isMarked,
        hanja: isHanja,
      });
    });
  }
  return { groups, decks, cards, report };
}

async function main() {
  const { id: userId } = await ensureDefaultUser(prisma);
  const existing = await prisma.group.count({ where: { userId } });
  if (existing > 0) {
    console.error(`User đã có ${existing} nhóm — dừng lại, không ghi đè nội dung đã có.`);
    process.exitCode = 1;
    return;
  }

  const decksJson = JSON.parse(
    readFileSync(join(process.cwd(), "prisma/seed-data/decks.json"), "utf-8"),
  ) as DecksJson;
  const syncState = await prisma.syncState.findUnique({ where: { userId } });
  const legacy = syncState
    ? (syncState.payload as unknown as LegacyState)
    : (JSON.parse(
        readFileSync(join(process.cwd(), "prisma/seed-data/vocab-state.json"), "utf-8"),
      ) as LegacyState);
  console.log(
    `Nguồn chỉnh sửa/đánh dấu: ${syncState ? `SyncState v${syncState.version}` : "seed file"}`,
  );

  const plan = buildImportPlan(decksJson, legacy);
  const now = new Date();
  await prisma.$transaction(async (tx) => {
    await tx.group.createMany({ data: plan.groups.map((g) => ({ ...g, userId })) });
    await tx.deck.createMany({ data: plan.decks.map((d) => ({ ...d, userId })) });
    await tx.card.createMany({
      data: plan.cards.map((c) => ({
        ...c,
        markedChangedAt: c.marked ? now : null,
        hanjaChangedAt: c.hanja ? now : null,
      })),
    });
  });

  const r = plan.report;
  console.log(
    `Đã tạo ${plan.groups.length} nhóm, ${plan.decks.length} bộ, ${plan.cards.length} thẻ ` +
      `(${r.edited} thẻ đã sửa, ${r.deleted} thẻ đã xoá, ⭐ ${r.marked}, 漢 ${r.hanja}).`,
  );
  if (r.skipped.length) {
    console.warn(`Bỏ qua ${r.skipped.length} entry lệch vị trí:\n  ${r.skipped.join("\n  ")}`);
  }
}

if (require.main === module) {
  main()
    .catch((err) => {
      console.error(err);
      process.exitCode = 1;
    })
    .finally(() => prisma.$disconnect());
}
