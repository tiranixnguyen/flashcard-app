import type { Request, Response } from "express";
import { prisma } from "../../config/db";
import { ensureDefaultUser } from "./defaultUser";
import { HttpError } from "./httpError";

/**
 * Bọc handler: lấy user mặc định, đổi `HttpError` thành đúng mã HTTP, lỗi
 * khác thành 500 (có log). Body luôn là `{ error }` — app đọc thông báo từ đó.
 */
export function handle(fn: (req: Request, res: Response, userId: string) => Promise<void>) {
  return async (req: Request, res: Response) => {
    try {
      const { id: userId } = await ensureDefaultUser(prisma);
      await fn(req, res, userId);
    } catch (err) {
      if (err instanceof HttpError) {
        res.status(err.status).json({ error: err.message });
        return;
      }
      console.error(`${req.method} ${req.originalUrl} thất bại:`, err);
      res.status(500).json({ error: "Lỗi máy chủ." });
    }
  };
}
