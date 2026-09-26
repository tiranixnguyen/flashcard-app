# Ghi chú backend

## `src/config/db.ts` — ba lỗi tiềm ẩn đã vá, đừng gỡ

1. Import `PrismaClient` từ `../../prisma/generated/prisma/client`, **không
   phải** thư mục `.../generated/prisma` (không có `index.ts`/`package.json`
   nên không resolve được).
2. Prisma 7 bắt buộc driver adapter (`@prisma/adapter-pg`) — thiếu thì throw ở
   query đầu tiên, không phải lúc construct.
3. Tự gọi `dotenv.config()` trong `db.ts` — `src/index.ts` không load `.env`,
   chỉ `prisma.config.ts` (cho CLI) có. Thiếu thì `DATABASE_URL` là
   `undefined` lúc `npm run dev` dù CLI Prisma chạy bình thường. Dùng
   `import dotenv from "dotenv"; dotenv.config();` — `import "dotenv/config"`
   thiếu khai báo kiểu dưới resolver của project.

## Cấu trúc

- `src/modules/common/` — `defaultUser` (user cố định, chưa có auth),
  `httpError` (`HttpError(status, message)`), `handle` (bọc route: lấy user,
  đổi `HttpError` → mã HTTP, lỗi khác → 500 có log).
- `src/modules/content/` — `/content`, `/groups`, `/decks`, `/cards`,
  `/cards/flags`. `wordInput.ts` kiểm tra + làm phẳng JSON nhập bộ.
- `src/modules/sessions/` — `/sessions` (chỉ thêm, id do client sinh).
- `src/scripts/` — `importContent` (một lần, DB mới), `exportContent` (DB →
  `frontend/assets/content.json`, chỉ đọc).

## Dữ liệu

Nguồn đúng là DB (`Group`/`Deck`/`Card`/`StudySession`). File JSON chỉ là điểm
khởi đầu / bản sao:

- `prisma/seed-data/decks.json` — 28 bộ gốc (574 mục, 3 nhóm). Chỉ `npm run
  import-content` đọc, cùng chỉnh sửa/⭐/漢 thật từ bảng `SyncState` cũ (không có
  thì `seed-data/vocab-state.json`). Chỉ chạy khi user **chưa có nhóm nào**.
- `frontend/assets/content.json` — bản xuất từ DB, định dạng `GET /content`.
  **Xuất lại** (`npm run export-content`) trước khi build bản phát hành; không
  sửa tay.
- Id: bộ gốc cố định (`g1..g3`, `ds1..ds30`, thẻ `<deckId>-<vị trí lúc
  import>`) để bản đóng gói khớp server; nhóm/bộ mới dùng cuid; thẻ mới dùng
  uuid (server sinh sẵn để ghi cả lô bằng 2 lệnh `createMany`).
- Schema cũ SM-2 (`UserCardProgress`, `LanguagePair`…) đã bỏ. `SyncState` chỉ
  còn cho `import-content`; xoá được khi chắc không cần import lại. `pg_dump`
  trước khi đổi schema nằm ở `backups/`.

## ⚠ Route ghi trên server dev

Smoke test ghi bằng tay trên server dev từng **ghi đè mất dữ liệu thật** của
`DEFAULT_USER_EMAIL` (server dev dùng đúng email thật). Muốn tự curl
POST/PATCH/DELETE: `pg_dump` trước (xem `backups/`) hoặc chạy server với
`DEFAULT_USER_EMAIL` khác. GET thì thoải mái. `npx vitest run` luôn an toàn.
