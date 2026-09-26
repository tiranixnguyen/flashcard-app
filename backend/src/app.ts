import express from "express";
import cors from "cors";
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
  app.use(sessionRouter);

  return app;
}
