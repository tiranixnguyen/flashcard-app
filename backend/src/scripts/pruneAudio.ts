/**
 * Xoá file nghe không còn thẻ nào trỏ tới (gỡ khỏi thẻ, xoá thẻ, thay file
 * khác đều để lại file cũ trong bảng Audio). Không route nào tự xoá: file đã
 * tải lên nhưng chưa kịp gắn vào thẻ (đang mở dialog sửa) vẫn phải còn.
 *
 * Chạy (từ thư mục backend/):  npm run prune-audio -- --dry-run   (chỉ liệt kê)
 *                              npm run prune-audio                (xoá thật)
 * Chỉ xoá file tạo trước đó hơn 1 ngày. Nên `pg_dump` trước khi xoá thật.
 */
import { prisma } from "../config/db";
import { ensureDefaultUser } from "../modules/common/defaultUser";

const MIN_AGE_MS = 24 * 60 * 60 * 1000;

async function main() {
  const dryRun = process.argv.includes("--dry-run");
  const { id: userId } = await ensureDefaultUser(prisma);
  const orphans = await prisma.audio.findMany({
    where: {
      userId,
      createdAt: { lt: new Date(Date.now() - MIN_AGE_MS) },
      frontCards: { none: {} },
      backCards: { none: {} },
      hintCards: { none: {} },
      noteCards: { none: {} },
    },
    select: { id: true, size: true, createdAt: true },
  });
  const kb = Math.round(orphans.reduce((n, a) => n + a.size, 0) / 1024);
  for (const a of orphans) console.log(`  ${a.id}  ${a.size} B  ${a.createdAt.toISOString()}`);
  if (dryRun) {
    console.log(`${orphans.length} file nghe mồ côi (${kb} KB) — chưa xoá (--dry-run).`);
    return;
  }
  const { count } = await prisma.audio.deleteMany({
    where: { id: { in: orphans.map((a) => a.id) } },
  });
  console.log(`Đã xoá ${count} file nghe mồ côi (${kb} KB).`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
