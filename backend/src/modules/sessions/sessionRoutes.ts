import { Router } from "express";
import { prisma } from "../../config/db";
import { handle } from "../common/handle";

/**
 * Lịch sử các lần học. Bản ghi chỉ thêm, không sửa, id do client sinh — gửi
 * lại (mạng chập chờn, hàng đợi offline) vẫn chỉ ra một bản ghi, và hai máy
 * học cùng lúc không ghi đè nhau. Gợi ý ôn lại do app tự tính từ lịch sử này.
 */
export const sessionRouter = Router();

export interface SessionInput {
  id: string;
  deckId: string;
  device: string;
  startedAt: string;
  endedAt: string;
  attempted: number;
  correct: number;
  masteredCount: number;
  totalCards: number;
  completed: boolean;
}

const MAX_BATCH = 500;

function isCount(v: unknown): v is number {
  return typeof v === "number" && Number.isInteger(v) && v >= 0;
}

function isDate(v: unknown): v is string {
  return typeof v === "string" && !Number.isNaN(Date.parse(v));
}

export function validateSession(v: unknown): string | null {
  if (typeof v !== "object" || v === null) return "phải là object";
  const s = v as Record<string, unknown>;
  if (typeof s.id !== "string" || s.id.length < 8 || s.id.length > 64) return "id không hợp lệ";
  if (typeof s.deckId !== "string" || !s.deckId) return "thiếu deckId";
  if (typeof s.device !== "string" || !s.device || s.device.length > 32)
    return "device không hợp lệ";
  if (!isDate(s.startedAt) || !isDate(s.endedAt)) return "startedAt/endedAt không hợp lệ";
  if (Date.parse(s.endedAt) < Date.parse(s.startedAt)) return "endedAt trước startedAt";
  for (const k of ["attempted", "correct", "masteredCount", "totalCards"] as const) {
    if (!isCount(s[k])) return `${k} phải là số nguyên không âm`;
  }
  if ((s.correct as number) > (s.attempted as number)) return "correct lớn hơn attempted";
  if ((s.masteredCount as number) > (s.totalCards as number))
    return "masteredCount lớn hơn totalCards";
  if (typeof s.completed !== "boolean") return "completed phải là boolean";
  return null;
}

sessionRouter.post(
  "/sessions",
  handle(async (req, res, userId) => {
    const sessions = (req.body as { sessions?: unknown } | null)?.sessions;
    if (!Array.isArray(sessions) || sessions.length === 0 || sessions.length > MAX_BATCH) {
      res.status(400).json({ error: `sessions phải là mảng 1–${MAX_BATCH} phần tử.` });
      return;
    }
    for (const [i, s] of sessions.entries()) {
      const err = validateSession(s);
      if (err) {
        res.status(400).json({ error: `sessions[${i}]: ${err}` });
        return;
      }
    }
    const input = sessions as SessionInput[];
    // Bộ đã bị xoá thì bỏ qua lần học của nó thay vì làm hỏng cả lô — nếu
    // không, hàng đợi offline trên máy sẽ kẹt mãi ở lô đó.
    const deckIds = [...new Set(input.map((s) => s.deckId))];
    const known = new Set(
      (
        await prisma.deck.findMany({
          where: { userId, id: { in: deckIds } },
          select: { id: true },
        })
      ).map((d) => d.id),
    );
    const rows = input.filter((s) => known.has(s.deckId));
    const { count } = await prisma.studySession.createMany({
      data: rows.map((s) => ({
        ...s,
        userId,
        startedAt: new Date(s.startedAt),
        endedAt: new Date(s.endedAt),
      })),
      skipDuplicates: true,
    });
    res.json({ received: input.length, inserted: count, unknownDeck: input.length - rows.length });
  }),
);

sessionRouter.get(
  "/sessions",
  handle(async (_req, res, userId) => {
    const sessions = await prisma.studySession.findMany({
      where: { userId },
      orderBy: { endedAt: "asc" },
      select: {
        id: true,
        deckId: true,
        device: true,
        startedAt: true,
        endedAt: true,
        attempted: true,
        correct: true,
        masteredCount: true,
        totalCards: true,
        completed: true,
      },
    });
    res.json({ sessions });
  }),
);
