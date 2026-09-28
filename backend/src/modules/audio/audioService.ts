import { createHash } from "node:crypto";
import type { PrismaClient } from "../../../prisma/generated/prisma/client";
import { HttpError } from "../common/httpError";

/** Giới hạn mỗi file — MP3 128 kbps ~ 2 phút. Đổi qua env `AUDIO_MAX_BYTES`. */
export const AUDIO_MAX_BYTES = Number(process.env.AUDIO_MAX_BYTES) || 2 * 1024 * 1024;

export const AUDIO_MIME = "audio/mpeg";

/**
 * MP3 bắt đầu bằng thẻ ID3 ("ID3", như file ElevenLabs xuất ra) hoặc thẳng
 * một khung MPEG (11 bit đồng bộ đầu là 1). Chỉ kiểm tra đầu file — đủ chặn
 * nhầm file (ảnh, m4a, wav…), không phải kiểm tra toàn vẹn.
 */
export function looksLikeMp3(bytes: Uint8Array): boolean {
  if (bytes.length < 4) return false;
  if (bytes[0] === 0x49 && bytes[1] === 0x44 && bytes[2] === 0x33) return true;
  return bytes[0] === 0xff && (bytes[1]! & 0xe0) === 0xe0;
}

/**
 * Lưu file nghe, trả về id. Cùng nội dung (trùng sha256) thì trả lại bản đã
 * có — tải lên lại không sinh bản thứ hai, và id không bao giờ đổi nội dung.
 */
export async function saveAudio(
  prisma: PrismaClient,
  userId: string,
  bytes: Uint8Array,
): Promise<{ id: string; size: number }> {
  if (bytes.length === 0) throw new HttpError(400, "File nghe đang trống.");
  if (bytes.length > AUDIO_MAX_BYTES) {
    throw new HttpError(413, `File nghe tối đa ${Math.floor(AUDIO_MAX_BYTES / 1024)} KB.`);
  }
  if (!looksLikeMp3(bytes)) throw new HttpError(415, "Chỉ nhận file MP3.");

  const sha256 = createHash("sha256").update(bytes).digest("hex");
  return prisma.audio.upsert({
    where: { userId_sha256: { userId, sha256 } },
    update: {},
    // Prisma cần Uint8Array trên ArrayBuffer thường; Buffer của Node có thể
    // nằm trên vùng nhớ chung -> chép ra (≤ vài MB).
    create: { userId, sha256, mime: AUDIO_MIME, size: bytes.length, bytes: new Uint8Array(bytes) },
    select: { id: true, size: true },
  });
}

export async function getAudio(prisma: PrismaClient, userId: string, id: string) {
  const audio = await prisma.audio.findFirst({
    where: { id, userId },
    select: { sha256: true, mime: true, bytes: true },
  });
  if (!audio) throw new HttpError(404, "Không tìm thấy file nghe.");
  return audio;
}

/** Id nào trong [ids] không phải file nghe của user — để báo lỗi khi gắn vào thẻ. */
export async function missingAudioIds(
  prisma: PrismaClient,
  userId: string,
  ids: string[],
): Promise<string[]> {
  if (ids.length === 0) return [];
  const found = await prisma.audio.findMany({
    where: { id: { in: ids }, userId },
    select: { id: true },
  });
  const have = new Set(found.map((a) => a.id));
  return ids.filter((id) => !have.has(id));
}

/**
 * Tách header `Range: bytes=a-b` (chỉ một khoảng). AVPlayer trên macOS/iOS
 * bắt buộc server trả 206 theo Range mới chịu phát/tua file qua HTTP.
 * `null` = không có Range hợp lệ -> trả cả file; `"unsatisfiable"` -> 416.
 */
export function parseRange(
  header: string | undefined,
  size: number,
): { start: number; end: number } | "unsatisfiable" | null {
  const m = /^bytes=(\d*)-(\d*)$/.exec(header?.trim() ?? "");
  if (!m || (m[1] === "" && m[2] === "")) return null;
  let start: number;
  let end: number;
  if (m[1] === "") {
    // "bytes=-500": 500 byte cuối.
    const suffix = Number(m[2]);
    if (suffix === 0) return "unsatisfiable";
    start = Math.max(0, size - suffix);
    end = size - 1;
  } else {
    start = Number(m[1]);
    end = m[2] === "" ? size - 1 : Math.min(Number(m[2]), size - 1);
  }
  if (start >= size || start > end) return "unsatisfiable";
  return { start, end };
}
