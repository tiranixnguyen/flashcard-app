import { randomUUID } from "node:crypto";
import type { PrismaClient } from "../../../prisma/generated/prisma/client";
import { DeckType } from "../../../prisma/generated/prisma/enums";
import { missingAudioIds } from "../audio/audioService";
import { HttpError } from "../common/httpError";
import { cleanAlts, cleanNote, cleanWordInputs, type WordInput } from "./wordInput";

export interface CardDto {
  id: string;
  position: number;
  front: string;
  back: string;
  hint: string | null;
  note: string | null;
  altAnswers: string[];
  typeAnswer: boolean;
  marked: boolean;
  hanja: boolean;
  passage: boolean;
  frontAudioId: string | null;
  backAudioId: string | null;
  hintAudioId: string | null;
  noteAudioId: string | null;
}

/** Các trường thẻ được gắn file nghe. */
export const AUDIO_FIELDS = ["frontAudioId", "backAudioId", "hintAudioId", "noteAudioId"] as const;
export type AudioField = (typeof AUDIO_FIELDS)[number];

/** Loại bộ từ hợp lệ (client hiển thị 듣기, 말하기, 읽기, 쓰기, 문법). */
export const DECK_TYPES = Object.values(DeckType);

/** `undefined` = không hợp lệ; `null` = bỏ phân loại. */
export function parseDeckType(value: unknown): DeckType | null | undefined {
  if (value === null) return null;
  return DECK_TYPES.find((t) => t === value);
}

export const MAX_DESCRIPTION = 500;

/**
 * Mô tả bộ: chữ thuần, bỏ khoảng trắng hai đầu, rỗng → `null`. `undefined` =
 * không hợp lệ (không phải chuỗi/null hoặc dài quá [MAX_DESCRIPTION]).
 */
export function parseDescription(value: unknown): string | null | undefined {
  if (value === null) return null;
  if (typeof value !== "string") return undefined;
  const text = value.replace(/\r\n?/g, "\n").trim();
  if (text.length > MAX_DESCRIPTION) return undefined;
  return text || null;
}

export interface DeckDto {
  id: string;
  groupId: string;
  name: string;
  position: number;
  type: DeckType | null;
  description: string | null;
  cards: CardDto[];
}

export interface GroupDto {
  id: string;
  name: string;
  position: number;
}

export interface ContentDto {
  groups: GroupDto[];
  decks: DeckDto[];
}

const cardSelect = {
  id: true,
  position: true,
  front: true,
  back: true,
  hint: true,
  note: true,
  altAnswers: true,
  typeAnswer: true,
  marked: true,
  hanja: true,
  passage: true,
  frontAudioId: true,
  backAudioId: true,
  hintAudioId: true,
  noteAudioId: true,
} as const;

const deckInclude = {
  cards: { select: cardSelect, orderBy: { position: "asc" } },
} as const;

function toDeckDto(d: {
  id: string;
  groupId: string;
  name: string;
  position: number;
  type: DeckType | null;
  description: string | null;
  cards: CardDto[];
}): DeckDto {
  return {
    id: d.id,
    groupId: d.groupId,
    name: d.name,
    position: d.position,
    type: d.type,
    description: d.description,
    cards: d.cards,
  };
}

/** Toàn bộ nội dung (nhóm + bộ + thẻ) của user — app tải một lần rồi cache. */
export async function getContent(prisma: PrismaClient, userId: string): Promise<ContentDto> {
  const [groups, decks] = await Promise.all([
    prisma.group.findMany({
      where: { userId },
      select: { id: true, name: true, position: true },
      orderBy: { position: "asc" },
    }),
    prisma.deck.findMany({
      where: { userId },
      include: deckInclude,
      orderBy: [{ groupId: "asc" }, { position: "asc" }],
    }),
  ]);
  return { groups, decks: decks.map(toDeckDto) };
}

export async function createGroup(
  prisma: PrismaClient,
  userId: string,
  name: string,
): Promise<GroupDto> {
  const last = await prisma.group.findFirst({
    where: { userId },
    orderBy: { position: "desc" },
    select: { position: true },
  });
  return prisma.group.create({
    data: { userId, name: name.trim(), position: (last?.position ?? -1) + 1 },
    select: { id: true, name: true, position: true },
  });
}

export async function renameGroup(
  prisma: PrismaClient,
  userId: string,
  groupId: string,
  name: string,
): Promise<GroupDto> {
  const { count } = await prisma.group.updateMany({
    where: { id: groupId, userId },
    data: { name: name.trim() },
  });
  if (count === 0) throw new HttpError(404, "Không tìm thấy nhóm.");
  return prisma.group.findUniqueOrThrow({
    where: { id: groupId },
    select: { id: true, name: true, position: true },
  });
}

/**
 * Ghi các thẻ vào cuối bộ bằng một câu lệnh duy nhất — một câu mỗi thẻ từng là
 * hàng trăm round-trip trong một transaction, dễ vượt timeout 5 giây mặc định
 * của Prisma.
 */
async function insertCards(
  tx: Pick<PrismaClient, "card">,
  deckId: string,
  words: WordInput[],
  startPosition: number,
): Promise<void> {
  await tx.card.createMany({
    data: cleanWordInputs(words).map((c, i) => ({
      id: randomUUID(),
      deckId,
      position: startPosition + i,
      ...c,
    })),
  });
}

export async function createDeck(
  prisma: PrismaClient,
  userId: string,
  input: {
    groupId: string;
    name: string;
    type?: DeckType | null;
    description?: string | null;
    words: WordInput[];
  },
): Promise<DeckDto> {
  return prisma.$transaction(async (tx) => {
    const group = await tx.group.findFirst({ where: { id: input.groupId, userId } });
    if (!group) throw new HttpError(404, "Không tìm thấy nhóm.");
    const last = await tx.deck.findFirst({
      where: { groupId: group.id },
      orderBy: { position: "desc" },
      select: { position: true },
    });
    const deck = await tx.deck.create({
      data: {
        userId,
        groupId: group.id,
        name: input.name.trim(),
        position: (last?.position ?? -1) + 1,
        type: input.type ?? null,
        description: input.description ?? null,
      },
    });
    await insertCards(tx, deck.id, input.words, 0);
    return toDeckDto(
      await tx.deck.findUniqueOrThrow({ where: { id: deck.id }, include: deckInclude }),
    );
  });
}

/** Sửa thông tin bộ (tên, loại, mô tả): thiếu trường = giữ nguyên, `null` = xoá. */
export async function updateDeck(
  prisma: PrismaClient,
  userId: string,
  deckId: string,
  patch: { name?: string; type?: DeckType | null; description?: string | null },
): Promise<DeckDto> {
  const { count } = await prisma.deck.updateMany({ where: { id: deckId, userId }, data: patch });
  if (count === 0) throw new HttpError(404, "Không tìm thấy bộ từ.");
  return toDeckDto(
    await prisma.deck.findUniqueOrThrow({ where: { id: deckId }, include: deckInclude }),
  );
}

/**
 * Thêm từ vào CUỐI bộ. Không có API chèn vào giữa: lịch sử học không phụ
 * thuộc vị trí nữa, nhưng giữ thứ tự ổn định giúp người học không bị đảo lộn
 * những gì đã quen.
 */
export async function appendCards(
  prisma: PrismaClient,
  userId: string,
  deckId: string,
  words: WordInput[],
): Promise<DeckDto> {
  return prisma.$transaction(async (tx) => {
    const deck = await tx.deck.findFirst({ where: { id: deckId, userId } });
    if (!deck) throw new HttpError(404, "Không tìm thấy bộ từ.");
    const last = await tx.card.findFirst({
      where: { deckId },
      orderBy: { position: "desc" },
      select: { position: true },
    });
    await insertCards(tx, deckId, words, (last?.position ?? -1) + 1);
    await tx.deck.update({ where: { id: deckId }, data: { updatedAt: new Date() } });
    return toDeckDto(
      await tx.deck.findUniqueOrThrow({ where: { id: deckId }, include: deckInclude }),
    );
  });
}

async function findOwnedCard(prisma: PrismaClient, userId: string, cardId: string) {
  const card = await prisma.card.findFirst({
    where: { id: cardId, deck: { userId } },
    select: { id: true },
  });
  if (!card) throw new HttpError(404, "Không tìm thấy thẻ.");
  return card;
}

export async function updateCard(
  prisma: PrismaClient,
  userId: string,
  cardId: string,
  input: {
    front: string;
    back: string;
    hint: string | null;
    /** Bỏ trống (`undefined`) thì giữ nguyên giải thích hiện tại — bản app
     * cũ chưa biết trường này không vô tình xoá mất; `null`/rỗng là xoá. */
    note?: string | null | undefined;
    altAnswers: string[];
    /** Bỏ trống thì giữ nguyên kiểu thẻ hiện tại. */
    typeAnswer?: boolean | undefined;
    /** File nghe từng trường: bỏ trống thì giữ, `null` là gỡ. */
    audio?: Partial<Record<AudioField, string | null>>;
  },
): Promise<CardDto> {
  await findOwnedCard(prisma, userId, cardId);
  const audio = input.audio ?? {};
  const missing = await missingAudioIds(
    prisma,
    userId,
    Object.values(audio).filter((id): id is string => typeof id === "string"),
  );
  if (missing.length) throw new HttpError(400, "Không tìm thấy file nghe — tải lên lại.");
  const hint = input.hint?.trim();
  return prisma.card.update({
    where: { id: cardId },
    data: {
      front: input.front.trim(),
      back: input.back.trim(),
      hint: hint ? hint : null,
      altAnswers: cleanAlts(input.altAnswers, input.back),
      ...(input.note === undefined ? {} : { note: cleanNote(input.note) }),
      ...(input.typeAnswer === undefined ? {} : { typeAnswer: input.typeAnswer }),
      ...audio,
    },
    select: cardSelect,
  });
}

/** Xoá thẻ. */
export async function deleteCard(
  prisma: PrismaClient,
  userId: string,
  cardId: string,
): Promise<void> {
  await findOwnedCard(prisma, userId, cardId);
  await prisma.card.delete({ where: { id: cardId } });
}

export interface FlagChange {
  cardId: string;
  marked?: boolean;
  hanja?: boolean;
  passage?: boolean;
  /** Thời điểm người dùng bấm (ISO). Lần bấm muộn nhất thắng. */
  changedAt: string;
}

/**
 * Áp các lần bật/tắt ⭐/漢/📖 gửi lên (có thể dồn từ lúc offline). Lần bấm cũ hơn
 * lần đã ghi thì bỏ qua; thẻ đã bị xoá cũng bỏ qua — không phải lỗi.
 */
export async function applyFlagChanges(
  prisma: PrismaClient,
  userId: string,
  changes: FlagChange[],
): Promise<{ applied: number; ignored: number }> {
  let applied = 0;
  for (const c of changes) {
    const at = new Date(c.changedAt);
    const scope = { id: c.cardId, deck: { userId } };
    if (c.marked !== undefined) {
      const r = await prisma.card.updateMany({
        where: { ...scope, OR: [{ markedChangedAt: null }, { markedChangedAt: { lt: at } }] },
        data: { marked: c.marked, markedChangedAt: at },
      });
      applied += r.count;
    }
    if (c.hanja !== undefined) {
      const r = await prisma.card.updateMany({
        where: { ...scope, OR: [{ hanjaChangedAt: null }, { hanjaChangedAt: { lt: at } }] },
        data: { hanja: c.hanja, hanjaChangedAt: at },
      });
      applied += r.count;
    }
    if (c.passage !== undefined) {
      const r = await prisma.card.updateMany({
        where: { ...scope, OR: [{ passageChangedAt: null }, { passageChangedAt: { lt: at } }] },
        data: { passage: c.passage, passageChangedAt: at },
      });
      applied += r.count;
    }
  }
  const requested = changes.reduce(
    (n, c) =>
      n +
      (c.marked !== undefined ? 1 : 0) +
      (c.hanja !== undefined ? 1 : 0) +
      (c.passage !== undefined ? 1 : 0),
    0,
  );
  return { applied, ignored: requested - applied };
}
