# CLAUDE.md

App học từ vựng Hàn → Việt (thẻ gõ đáp án hoặc tự chấm, ôn giãn cách). Giao diện + comment:
**tiếng Việt**. Agent khác: xem `AGENTS.md`.

- `frontend/` — Flutter + Riverpod (codegen). Học offline hoàn toàn, có mạng
  thì tự đồng bộ nền. **Điện thoại chỉ học (+ ⭐/漢/📖); Mac/web học + soạn nhóm/
  bộ/thẻ (cần mạng).**
- `backend/` — Express 5 + Prisma 7 + Postgres. Server là nguồn đúng cho nội
  dung và lịch sử học. Chưa có auth: một user cố định `DEFAULT_USER_EMAIL`.

## Tài liệu chi tiết — đọc khi đụng vùng đó

| File | Nội dung |
|---|---|
| `docs/study-algorithm.md` | thuật toán ôn trong lượt, deck ảo, gợi ý ôn lại, đồng bộ offline-first |
| `docs/frontend.md` | kiến trúc, UI/theme/phím tắt, bàn phím Hàn, tự cuộn, mạng/`API_BASE_URL`, font bundle (+ hash tải lại) |
| `docs/backend.md` | 3 fix trong `db.ts`, cấu trúc module, dữ liệu/seed/id, sự cố ghi đè dữ liệu |
| `docs/testing.md` | danh sách test, bẫy widget test |

## Lệnh

```bash
# frontend/ — LUÔN dùng `fvm flutter` (SDK ghim ở .fvmrc), không dùng flutter toàn cục
fvm flutter pub get
fvm dart run build_runner build   # sau khi sửa @riverpod; *.g.dart CÓ commit
fvm dart analyze                  # phải sạch (flutter analyze không chạy riverpod_lint)
fvm flutter test
fvm flutter run -d macos          # điện thoại thật: --dart-define=API_BASE_URL=http://<IP-LAN>:3000

# backend/ (cần `docker compose up -d` ở gốc repo)
npx prisma generate               # bắt buộc sau clone/đổi schema (generated/ không commit)
npx prisma migrate dev
npm run dev                       # http://localhost:3000
npx vitest run                    # có test chạm Postgres thật (user test riêng, an toàn)
npm run lint                      # phải sạch
npm run export-content            # DB → frontend/assets/content.json (trước khi build phát hành)
```

## Quy tắc bắt buộc

- `domain/` (`StudyEngine`…) là Dart thuần — không import `package:flutter`.
  Random phải tiêm được. Widget không cầm `StudyEngine`; UI chỉ thấy
  `StudySessionState` bất biến (`_snapshot()`).
- Sửa `StudyEngine` → thêm test vào `study_engine_test.dart`.
- `ContentApi` chỉ được ném `ApiException` (kể cả lỗi parse).
- Widget test: override **mọi** provider chạm I/O (asset, store, API,
  connectivity, clock, audio player/picker), không `pumpAndSettle` ở màn học — thiếu là treo im lặng.
- `MaterialApp` luôn có `theme: buildAppTheme(...)`; màu disabled đặt ở theme.
- Dropdown chọn deck là controlled widget (không `DropdownButtonFormField`).
- Phím tắt bắt ở `HardwareKeyboard`, không `Shortcuts`/`Focus`; "Xem đáp án"
  là `Cmd+/` (không phải `Cmd+Space`).
- Font: chỉ dùng weight/style đã bundle trong `assets/fonts/`; thêm mới thì
  bundle file theo (italic là file riêng).
- `baseUrl` theo nền tảng; check `kIsWeb` trước `Platform.*`. Đừng gỡ quyền
  mạng trong entitlements/Info.plist/AndroidManifest.
- Backend: đừng gỡ 3 fix trong `src/config/db.ts` (lý do trong comment và
  `docs/backend.md`). Lỗi nghiệp vụ ném `HttpError`, route bọc bằng `handle()`.
- **Không tự curl route ghi (POST/PATCH/DELETE) vào server dev** — nó dùng user
  thật, đã từng mất dữ liệu. Cần thì `pg_dump` trước (`backups/`) hoặc đổi
  `DEFAULT_USER_EMAIL`. GET thoải mái.
- Không sửa tay `frontend/assets/content.json`. Thêm biến env → cập nhật
  `backend/.env.example`.
- Trước khi báo xong: analyze + test frontend sạch; đụng backend thì `tsc`,
  lint, vitest sạch.
- File này nạp vào context mọi phiên — giữ ngắn. Ghi chú mới: chi tiết/lý do
  vào `docs/`, ở đây chỉ thêm tối đa một dòng quy tắc.
