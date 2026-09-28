import express, { type NextFunction, type Request, type Response } from "express";
import cors from "cors";
import { audioRouter } from "./modules/audio/audioRoutes";
import { contentRouter } from "./modules/content/contentRoutes";
import { sessionRouter } from "./modules/sessions/sessionRoutes";

/**
 * Tách khỏi `index.ts` để test import được `app` mà không kéo theo
 * `listen()` — test tự chọn cổng (0 = ngẫu nhiên) và tự đóng server.
 */
export function createApp() {
  const app = express();
  app.use(cors());
  // Mặc định 100KB — một bộ từ dài kèm chú thích chiết tự Hán tự dễ vượt.
  app.use(express.json({ limit: "2mb" }));

  app.get("/health", (_req, res) => res.json({ status: "ok" }));
  app.use(contentRouter);
  app.use(audioRouter);
  app.use(sessionRouter);

  // Lỗi ném ra trước khi vào `handle()` (body-parser: body quá lớn, JSON
  // hỏng) — mặc định Express trả trang HTML, app chỉ đọc được `{ error }`.
  app.use(
    (err: { status?: number; type?: string }, _req: Request, res: Response, next: NextFunction) => {
      if (res.headersSent) return next(err);
      const status = err.status ?? 500;
      const error =
        err.type === "entity.too.large"
          ? "Dữ liệu gửi lên quá lớn."
          : status < 500
            ? "Yêu cầu không hợp lệ."
            : "Lỗi máy chủ.";
      if (status >= 500) console.error(err);
      res.status(status).json({ error });
    },
  );

  return app;
}
