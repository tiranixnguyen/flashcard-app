import { Router } from "express";
import { prisma } from "../../config/db";
import { handle } from "../common/handle";
import {
  appendCards,
  applyFlagChanges,
  createDeck,
  createGroup,
  deleteCard,
  getContent,
  renameGroup,
  updateCard,
  type FlagChange,
} from "./contentService";
import { parseWordInputs } from "./wordInput";

/**
 * Nội dung học: nhóm, bộ từ, thẻ. Chỉ Mac/web được tạo/sửa (cần có mạng); điện
 * thoại chỉ đọc `GET /content` và bật/tắt ⭐/漢 qua `POST /cards/flags`.
 */
export const contentRouter = Router();

const MAX_NAME = 120;

function nameOf(body: unknown): string | null {
  const name = (body as { name?: unknown } | null)?.name;
  if (typeof name !== "string") return null;
  const trimmed = name.trim();
  return trimmed && trimmed.length <= MAX_NAME ? trimmed : null;
}

contentRouter.get(
  "/content",
  handle(async (_req, res, userId) => {
    res.json(await getContent(prisma, userId));
  }),
);

contentRouter.post(
  "/groups",
  handle(async (req, res, userId) => {
    const name = nameOf(req.body);
    if (!name) {
      res.status(400).json({ error: `Tên nhóm không được trống (tối đa ${MAX_NAME} ký tự).` });
      return;
    }
    res.status(201).json(await createGroup(prisma, userId, name));
  }),
);

contentRouter.patch(
  "/groups/:id",
  handle(async (req, res, userId) => {
    const name = nameOf(req.body);
    if (!name) {
      res.status(400).json({ error: `Tên nhóm không được trống (tối đa ${MAX_NAME} ký tự).` });
      return;
    }
    res.json(await renameGroup(prisma, userId, String(req.params.id), name));
  }),
);

contentRouter.post(
  "/decks",
  handle(async (req, res, userId) => {
    const body = (req.body ?? {}) as Record<string, unknown>;
    const name = nameOf(body);
    if (!name) {
      res.status(400).json({ error: `Tên bộ không được trống (tối đa ${MAX_NAME} ký tự).` });
      return;
    }
    if (typeof body.groupId !== "string" || !body.groupId) {
      res.status(400).json({ error: "Thiếu groupId." });
      return;
    }
    const words = parseWordInputs(body.words);
    if (!words.ok) {
      res.status(400).json({ error: words.error });
      return;
    }
    res
      .status(201)
      .json(await createDeck(prisma, userId, { groupId: body.groupId, name, words: words.value }));
  }),
);

contentRouter.post(
  "/decks/:id/cards",
  handle(async (req, res, userId) => {
    const words = parseWordInputs((req.body as { words?: unknown } | null)?.words);
    if (!words.ok) {
      res.status(400).json({ error: words.error });
      return;
    }
    res.json(await appendCards(prisma, userId, String(req.params.id), words.value));
  }),
);

contentRouter.patch(
  "/cards/:id",
  handle(async (req, res, userId) => {
    const body = (req.body ?? {}) as Record<string, unknown>;
    const { front, back, hint, note, altAnswers, typeAnswer } = body;
    if (typeof front !== "string" || !front.trim() || typeof back !== "string" || !back.trim()) {
      res.status(400).json({ error: "Cần đủ mặt trước và mặt sau." });
      return;
    }
    if (typeAnswer !== undefined && typeof typeAnswer !== "boolean") {
      res.status(400).json({ error: "typeAnswer phải là true/false." });
      return;
    }
    if (hint !== undefined && hint !== null && typeof hint !== "string") {
      res.status(400).json({ error: "hint phải là chuỗi." });
      return;
    }
    if (note !== undefined && note !== null && typeof note !== "string") {
      res.status(400).json({ error: "note phải là chuỗi." });
      return;
    }
    if (
      altAnswers !== undefined &&
      !(Array.isArray(altAnswers) && altAnswers.every((a) => typeof a === "string"))
    ) {
      res.status(400).json({ error: "altAnswers phải là mảng chuỗi." });
      return;
    }
    res.json(
      await updateCard(prisma, userId, String(req.params.id), {
        front,
        back,
        hint: (hint as string | null | undefined) ?? null,
        note: note as string | null | undefined,
        altAnswers: (altAnswers as string[] | undefined) ?? [],
        typeAnswer,
      }),
    );
  }),
);

contentRouter.delete(
  "/cards/:id",
  handle(async (req, res, userId) => {
    await deleteCard(prisma, userId, String(req.params.id));
    res.status(204).end();
  }),
);

contentRouter.post(
  "/cards/flags",
  handle(async (req, res, userId) => {
    const changes = (req.body as { changes?: unknown } | null)?.changes;
    if (!Array.isArray(changes) || changes.length > 1000) {
      res.status(400).json({ error: "changes phải là mảng (tối đa 1000)." });
      return;
    }
    for (const [i, c] of changes.entries()) {
      const ok =
        typeof c === "object" &&
        c !== null &&
        typeof c.cardId === "string" &&
        typeof c.changedAt === "string" &&
        !Number.isNaN(Date.parse(c.changedAt)) &&
        (c.marked === undefined || typeof c.marked === "boolean") &&
        (c.hanja === undefined || typeof c.hanja === "boolean");
      if (!ok) {
        res.status(400).json({ error: `changes[${i}] không hợp lệ.` });
        return;
      }
    }
    res.json(await applyFlagChanges(prisma, userId, changes as FlagChange[]));
  }),
);
