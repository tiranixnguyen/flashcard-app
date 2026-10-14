# Test

## Frontend — `fvm flutter test`

- `study_engine_test.dart` — thuật toán trên dữ liệu giả (dựng qua
  `support/fixtures.dart` → `buildStudyCatalog`, đúng đường chạy thật), hạt
  giống cố định. Gồm `replaceContent` (sửa/xoá/thêm thẻ giữa lượt), bỏ cờ
  trong deck ⭐/漢/📖 và thẻ tự chấm (lật không tính điểm, chưa lật không chấm
  được, "Nhớ"/"Chưa nhớ" đúng nhánh), mỗi thẻ độc lập (thuộc/xoá một thẻ
  không kéo thẻ khác).
  Fixture `contentDeck` áp `defaultTypeAnswer` như server, nên từ ngắn trong
  test là thẻ gõ đáp án; muốn thẻ tự chấm thì ghi `"typeAnswer": false`.
- `review_schedule_test.dart` — gợi ý ôn lại: giãn 1→3→7→14→30→60, tụt về đầu
  khi < 80%, học sớm không nhảy bậc, học dở không tính, so theo ngày lịch.
- `deck_import_test.dart` — JSON dán từ AI (khối ` ```json `, mảng trần,
  `followUp` cũ bị từ chối, lỗi đúng vị trí, giới hạn 500 khớp server), `typeAnswer` mặc định
  theo độ dài mặt sau / ghi rõ thì giữ.
- `content_asset_test.dart` — trên chính `assets/content.json`: id không trùng,
  không còn `parentId`, dựng catalog không rơi thẻ/cờ.
- `content_api_test.dart` — `DioContentApi` ở tầng HTTP thật (fake
  `HttpClientAdapter`): parse, `offline` vs server từ chối (thông báo từ body),
  body sai định dạng/HTML vẫn thành `ApiException`, body gửi đi đúng định dạng,
  cache cũ `kr`/`vi` vẫn đọc được, loại bộ (thiếu/giá trị lạ → `null`, gửi
  khi tạo bộ, `PATCH /decks/:id`), mô tả bộ. Upload file nghe gửi bytes thô, PATCH thẻ gửi
  đủ 4 id file nghe.
- `linkify_test.dart` — tách link `http(s)://` trong mô tả bộ: ghép lại đúng
  chữ gốc, bỏ dấu câu cuối, giữ ngoặc cân bằng, bỏ qua link không có host.
- `audio_playback_test.dart` — trình phát dùng chung: phát/tạm dừng/phát lại
  từ đầu, chuyển file, nạp lỗi, sang thẻ lúc đang nạp thì không phát;
  `visibleAudioFields` cho `Cmd+.`.
- `study_reading_view_test.dart` — smoke test UI qua `_FakeApi` (server trong
  bộ nhớ) + `MemoryStore`: ghi lần học (hết bộ / bỏ dở / nháp sót), hàng đợi
  offline tự gửi khi có mạng, ⭐/漢/📖 offline (`_FakeApi` áp cờ vào server giả
  như thật), thứ tự ô chọn bộ (deck ảo trên cùng), menu ô chọn bộ ("+ Bộ mới"
  dính đáy khi cuộn, chọn bộ, Enter không lọt xuống màn học), lịch sử gộp máy khác, soạn nội dung
  chỉ trên Mac/web (kể cả ô "Nhập đáp án" khi tạo bộ / sửa thẻ, chọn/đổi loại
  bộ + nhãn trong ô chọn bộ, đổi loại offline báo lỗi, thêm/sửa/xoá mô tả),
  mô tả bộ (link mở qua `_FakeLinkLauncher` trên máy tính, điện thoại là chữ
  thường, bộ ảo không hiện), bộ rỗng không
  crash, thẻ tự chấm (lật, Nhớ/Chưa nhớ, phím tắt Space/1/0), file nghe (nút
  theo trường, dừng khi sang thẻ, `Cmd+.`, offline, điện thoại không có, dialog
  gắn/gỡ/tải lên), phóng chữ thẻ (`Cmd+=/−/0`, nút "Aa", nút/badge giữ cỡ,
  không mất chữ đang gõ, 160% trên màn 360pt không tràn).
- `hint_box_test.dart` — chú thích trên thẻ theo nền tảng: máy tính/web giới
  hạn `hintVisibleLines` dòng rồi cuộn; điện thoại cắt bớt, bấm mở bảng đầy đủ.
  Dựng trong `IntrinsicHeight` (ngữ cảnh khắt khe nhất) — đừng dùng
  `LayoutBuilder` trong `HintBox` (ném lỗi dưới `IntrinsicHeight`).
- `note_format_test.dart` — dựng lại cấp lồng danh sách bị mất thụt lề.
- `answer_note_test.dart` — giải thích Markdown (bảng, code, xuống dòng đơn)
  layout được trong `IntrinsicHeight`; máy tính cuộn trong khung, điện thoại
  cắt bớt + bảng đầy đủ.
- `bundled_fonts_test.dart` — 6 file font có trong `AssetManifest` (đúng API
  `google_fonts` dùng).

Nhánh dễ hỏng nhất của engine (đều có test, đừng làm gãy): tự xác nhận đúng
(hoàn tác nhánh sai), mang tiến trình theo id khi nội dung
đổi giữa lượt, ⭐/漢 trong hàng đợi áp lại lên nội dung vừa tải, bỏ cờ ngay
trong deck ⭐/漢 (thẻ ở lại tới khi sang thẻ tiếp rồi rơi hẳn —
`_pruneUnflagged`), bộ rỗng hiện màn "chưa có thẻ".

### Bẫy trong widget test

- **Override mọi provider chạm I/O thật:** `bundledContentProvider`,
  `localStoreProvider` (`LocalStore(MemoryStore())`), `contentApiProvider`,
  `connectivityGatewayProvider`, `audioPlayerGatewayProvider` +
  `audioFilePickerProvider` (bản giả trong `support/fake_audio.dart`),
  `linkLauncherProvider` (url_launcher),
  `cardZoomProvider` (SharedPreferences — kể cả test riêng `HintBox`/
  `AnswerNote`, vì bảng xem đầy đủ bọc `CardTextZoom`), nên cả
  `clockProvider`. `testWidgets` chạy
  trong fake-async nên I/O thật (asset qua `rootBundle`, platform channel,
  mạng) không bao giờ xong → kẹt loading, chỉ thấy timeout.
- **Không `pumpAndSettle` ở màn học** — lúc loading có
  `CircularProgressIndicator` chạy vô hạn. Bơm `tester.pump(...)` trong vòng lặp.
- **Mặc định là Android = điện thoại** nên nút soạn nội dung không hiện; test
  Mac/web dùng `TargetPlatformVariant` macOS/windows.
- **Màn test 800×600 không chứa hết trang** (cả dialog cuộn được) — bấm qua
  `tapVisible` (cuộn tới trước), đừng `tap` thẳng.

## Backend — `npx vitest run` (cần `docker compose up -d`)

- `wordInput.test.ts`, `importContent.test.ts` — thuần (import chạy trên
  `seed-data/` thật).
- `audioService.test.ts` — thuần: nhận diện MP3, tách header `Range`.
- `content.integration.test.ts`, `sessions.integration.test.ts`,
  `audio.integration.test.ts` — Express app
  thật + Postgres dev thật (`useTestServer()` + `fetch`, không mock Prisma).
  An toàn vì `vitest.setup.ts` đổi `DEFAULT_USER_EMAIL` sang email test trước
  khi module nào nạp; `useTestServer()` từ chối chạy nếu email không chứa
  "test". `fileParallelism: false` vì các file cùng dọn/ghi một user test.
