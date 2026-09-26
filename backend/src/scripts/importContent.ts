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
 */
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { prisma } from "../config/db";
import { ensureDefaultUser } from "../modules/common/defaultUser";
import { expandWordInputs, type WordInput } from "../modules/content/wordInput";

interface DecksJson {
  vocabGroups: { id: string; name: string }[];
  decks: { id: string; name: string; group?: string; category?: string; words: WordInput[] }[];
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
    parentId: string | null;
    kr: string;
    vi: string;
    hint: string | null;
    altAnswers: string[];
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

    const expanded = expandWordInputs(d.words);
    const deletedIndexes = new Set<number>();
    expanded.forEach((c, i) => {
      const k = key(d.id, i);
      const matches = (e: LegacyEntry | undefined) => {
        if (!e) return false;
        if (e.baseKr === c.kr) return true;
        report.skipped.push(`${k}: baseKr "${e.baseKr}" ≠ "${c.kr}"`);
        return false;
      };

      const parentGone = c.parentOffset !== null && deletedIndexes.has(c.parentOffset);
      const edit = overlay.get(k);
      if (parentGone || (matches(edit) && edit!.deleted)) {
        deletedIndexes.add(i);
        report.deleted++;
        return;
      }
      const isEdited = edit !== undefined && edit.baseKr === c.kr;
      if (isEdited) report.edited++;
      const isMarked = matches(marked.get(k));
      const isHanja = matches(hanja.get(k));
      if (isMarked) report.marked++;
      if (isHanja) report.hanja++;

      cards.push({
        id: `${d.id}-${i}`,
        deckId: d.id,
        position: i,
        parentId: c.parentOffset === null ? null : `${d.id}-${c.parentOffset}`,
        kr: isEdited ? edit!.kr : c.kr,
        vi: isEdited ? edit!.vi : c.vi,
        hint: isEdited ? edit!.hint : c.hint,
        altAnswers: isEdited ? (edit!.altAnswers ?? []) : c.altAnswers,
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
    // Thẻ gốc trước, thẻ ngữ cảnh sau — parentId phải trỏ tới thẻ đã tồn tại.
    const roots = plan.cards.filter((c) => c.parentId === null);
    const followUps = plan.cards.filter((c) => c.parentId !== null);
    const withStamps = (c: ImportPlan["cards"][number]) => ({
      ...c,
      markedChangedAt: c.marked ? now : null,
      hanjaChangedAt: c.hanja ? now : null,
    });
    await tx.card.createMany({ data: roots.map(withStamps) });
    await tx.card.createMany({ data: followUps.map(withStamps) });
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
