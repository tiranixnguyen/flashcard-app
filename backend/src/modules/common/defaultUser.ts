import type { PrismaClient } from "../../../prisma/generated/prisma/client";

/**
 * Chưa có đăng nhập — toàn bộ backend phục vụ đúng một user cố định. Đây là
 * lựa chọn tạm thời có chủ đích (xem docs/backend.md), không phải sơ suất quên làm
 * auth. Khi thêm auth thật, thay lời gọi `ensureDefaultUser` bằng user lấy từ
 * request đã xác thực.
 */
export const DEFAULT_USER_EMAIL = process.env.DEFAULT_USER_EMAIL || "local@vocab-app.local";

/**
 * Tạo user mặc định nếu chưa có. Idempotent — gọi lại nhiều lần vẫn an toàn,
 * nên có thể gọi ở đầu mỗi request thay vì chỉ lúc khởi động server (đơn giản
 * hơn, tránh phải theo dõi trạng thái "đã ensure hay chưa" qua các lần reload
 * của ts-node-dev).
 */
export async function ensureDefaultUser(prisma: PrismaClient): Promise<{ id: string }> {
  return prisma.user.upsert({
    where: { email: DEFAULT_USER_EMAIL },
    update: {},
    create: {
      email: DEFAULT_USER_EMAIL,
      // Chưa có auth nên chưa có mật khẩu thật; giá trị này không bao giờ
      // được dùng để xác thực. Không phải checksum hay secret gì cả.
      passwordHash: "unused-no-auth-yet",
    },
    select: { id: true },
  });
}
