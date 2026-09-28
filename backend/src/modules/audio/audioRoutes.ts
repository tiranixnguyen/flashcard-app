import express, { Router } from "express";
import { prisma } from "../../config/db";
import { handle } from "../common/handle";
import { AUDIO_MAX_BYTES, getAudio, parseRange, saveAudio } from "./audioService";

/**
 * File nghe gắn vào thẻ. Tải lên bằng thân request là bytes MP3 thô
 * (`Content-Type: audio/mpeg`) — không cần multipart. Chỉ Mac/web tải lên và
 * phát; điện thoại không gọi các route này.
 */
export const audioRouter = Router();

audioRouter.post(
  "/audio",
  // Vượt giới hạn -> body-parser ném 413, bộ bắt lỗi trong app.ts trả JSON.
  express.raw({ type: "audio/*", limit: AUDIO_MAX_BYTES }),
  handle(async (req, res, userId) => {
    if (!Buffer.isBuffer(req.body)) {
      res.status(415).json({ error: "Gửi file MP3 với Content-Type: audio/mpeg." });
      return;
    }
    res.status(201).json(await saveAudio(prisma, userId, req.body));
  }),
);

audioRouter.get(
  "/audio/:id",
  handle(async (req, res, userId) => {
    const audio = await getAudio(prisma, userId, String(req.params.id));
    const etag = `"${audio.sha256}"`;
    // Nội dung của một id không bao giờ đổi -> cache vĩnh viễn.
    res.set({
      "Content-Type": audio.mime,
      "Cache-Control": "public, max-age=31536000, immutable",
      ETag: etag,
      "Accept-Ranges": "bytes",
    });
    if (req.headers["if-none-match"] === etag) {
      res.status(304).end();
      return;
    }

    const bytes = Buffer.from(audio.bytes);
    const range = parseRange(req.headers.range, bytes.length);
    if (range === "unsatisfiable") {
      res.status(416).set("Content-Range", `bytes */${bytes.length}`).end();
      return;
    }
    if (range) {
      res
        .status(206)
        .set("Content-Range", `bytes ${range.start}-${range.end}/${bytes.length}`)
        .send(bytes.subarray(range.start, range.end + 1));
      return;
    }
    res.send(bytes);
  }),
);
