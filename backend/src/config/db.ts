import dotenv from "dotenv";
import { PrismaPg } from "@prisma/adapter-pg";
// Phải trỏ thẳng vào client.ts, không phải thư mục "prisma/generated/prisma"
// — thư mục đó không có index.ts/package.json nên import bằng đường dẫn
// thư mục sẽ không resolve được (ts-node-dev từng "nuốt" lỗi này vì trước khi
// có route /sync, không có chỗ nào thực sự import module này).
import { PrismaClient } from "../../prisma/generated/prisma/client";

// Không dùng `import "dotenv/config"`: subpath export "./config" của dotenv
// không kèm khai báo kiểu, nên TypeScript báo "Cannot find module" dưới cấu
// hình resolver của project này. Gọi .config() tường minh để có type-check.
//
// Bắt buộc phải load ở đây: `src/index.ts` chưa từng gọi dotenv (chỉ
// `prisma.config.ts` — dùng cho CLI `prisma migrate`/`generate` — có gọi).
// Thiếu dòng này, DATABASE_URL sẽ là undefined lúc chạy `npm run dev`, và lỗi
// chỉ lộ ra khi có query đầu tiên chạm DB (không phải lúc construct client).
dotenv.config();

// Prisma 7 không còn tự mở kết nối từ `datasource.url` trong schema — client
// yêu cầu driver adapter tường minh, thiếu adapter sẽ throw ngay ở query đầu
// tiên (không throw lúc `new PrismaClient()`, nên lỗi này dễ lọt qua smoke test
// hời hợt). Xem https://pris.ly/d/driver-adapters
const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });

export const prisma = new PrismaClient({ adapter });
