# Flashcard App — Học từ vựng tiếng Hàn

App học từ vựng Hàn → Việt: nhìn nghĩa tiếng Việt, gõ từ tiếng Hàn, ôn lại theo
lịch giãn cách cho tới khi thuộc; app nhớ lịch sử các lần học từng bộ và gợi ý
khi nào nên ôn lại.

Học được offline hoàn toàn — kể cả font chữ Hàn cũng đóng gói sẵn trong app
(~20MB); có mạng thì tự đồng bộ nền với backend. **Điện thoại chỉ dành cho việc
học, không thể sửa và tạo; Mac/web có thể học, tạo và sửa bộ từ.**

## Tính năng

- Tạo thêm nhóm và bộ mới
  trên Mac/web
- Ôn theo Leitner trong mỗi lượt học: đúng 3 lần liên tiếp thì thẻ được coi là
  đã thuộc
- Lịch sử học từng bộ (gộp mọi máy) + gợi ý ôn lại: học hết bộ với ≥ 80% đúng
  thì hẹn ôn sau 1 → 3 → 7 → 14 → 30 → 60 ngày, dưới 80% thì hẹn ngày mai
- Chấp nhận nhiều đáp án đúng cho một thẻ
- "Thật ra tôi viết đúng" — bỏ qua lỗi gõ nhầm mà không mất streak
- Thẻ ngữ cảnh: học xong một từ thì được hỏi ngay câu dùng từ đó
- Đánh dấu ⭐ từ khó nhớ và 漢 từ Hán Hàn, mỗi loại thành một bộ ôn riêng
- Bộ 20 thẻ ngẫu nhiên
- Mac/web: tạo bộ bằng cách dán JSON từ AI (có nút chép sẵn prompt tách từ
  để dán vào AI cùng đoạn tiếng Hàn), thêm từ, sửa / xoá thẻ
- Phím tắt (macOS/web): `Enter` chấm bài, `⌘+Enter` đã thuộc, `⌘+/` xem
  đáp án, `Enter` hoặc `⌘+Enter` sang thẻ tiếp sau khi đã trả lời
- Trên điện thoại: focus ô gõ tiếng Hàn thì bàn phím tự chuyển sang tiếng Hàn,
  rời ô thì trở lại bàn phím cũ; trang tự cuộn để vừa thấy ô trả lời vừa thấy
  tên bộ từ
- Giao diện sáng/tối
- Đồng bộ nền với server khi có mạng — mất mạng vẫn học và đánh dấu ⭐/漢 bình
  thường, lần học và dấu đợi có mạng trở lại tự gửi đi

## Chạy thử

Flutter SDK được ghim qua [fvm](https://fvm.app) ở `frontend/.fvmrc`.

```bash
cd frontend
fvm flutter pub get
fvm flutter run -d chrome    # hoặc -d macos
```

Chạy trên điện thoại thật thì chỉ địa chỉ LAN của máy đang chạy backend (điện
thoại và máy tính cùng mạng Wi-Fi):

```bash
fvm flutter run --dart-define=API_BASE_URL=http://$(ipconfig getifaddr en0):3000
```

Không có backend app vẫn học được bình thường với bộ từ đóng gói sẵn
(`assets/content.json`), chỉ là không đồng bộ được giữa các thiết bị và không
tạo/sửa bộ từ được.

## Backend

Express + Prisma + Postgres. Giữ nội dung (nhóm/bộ/thẻ) và lịch sử học — chưa
có đăng nhập, tạm thời dùng một user cố định.

```bash
docker compose up -d
cd backend && npm install && npx prisma generate && npx prisma migrate dev
npm run import-content   # lần đầu, DB trống: nạp 28 bộ gốc
npm run dev              # http://localhost:3000
npx vitest run           # chạy test — cần Postgres đang bật
npm run export-content   # cập nhật bản đóng gói trong app trước khi build
```

## Cấu trúc

```
frontend/   Flutter + Riverpod — app chạy được, offline-first
backend/    Express 5 + Prisma 7 + Postgres — nội dung + lịch sử học
docs/       study-algorithm · frontend · backend · testing — ghi chú chi tiết
CLAUDE.md   quy tắc ngắn cho coding agent (AGENTS.md trỏ về đây)
```

## Phát triển

```bash
cd frontend
fvm dart run build_runner build   # sau khi sửa provider @riverpod
fvm flutter analyze
fvm flutter test
```

Quy tắc cho coding agent: [`CLAUDE.md`](./CLAUDE.md); chi tiết theo vùng (frontend, backend, test, thuật toán): [`docs/`](./docs).
