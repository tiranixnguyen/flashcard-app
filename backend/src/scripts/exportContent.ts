/**
 * Xuất nội dung hiện tại của user mặc định (giống hệt `GET /content`) ra
 * frontend/assets/content.json — bản đóng gói app dùng khi máy chưa từng tải
 * được nội dung từ server (cài mới + không có mạng). Chỉ đọc DB.
 *
 * Chạy (từ thư mục backend/):  npm run export-content
 * Nên chạy lại trước khi build bản phát hành để bản đóng gói không quá cũ.
 */
import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { prisma } from "../config/db";
import { ensureDefaultUser } from "../modules/common/defaultUser";
import { getContent } from "../modules/content/contentService";

async function main() {
  const { id: userId } = await ensureDefaultUser(prisma);
  const content = await getContent(prisma, userId);
  if (content.groups.length === 0) {
    console.error("User chưa có nội dung — chạy `npm run import-content` trước.");
    process.exitCode = 1;
    return;
  }
  const out = join(process.cwd(), "../frontend/assets/content.json");
  writeFileSync(out, `${JSON.stringify(content, null, 1)}\n`);
  const cards = content.decks.reduce((n, d) => n + d.cards.length, 0);
  console.log(
    `Đã xuất ${content.groups.length} nhóm, ${content.decks.length} bộ, ${cards} thẻ → ${out}`,
  );
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
