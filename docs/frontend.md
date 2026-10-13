# Ghi chú frontend (Flutter)

Chi tiết + lý do cho các quy tắc tóm tắt trong `CLAUDE.md`. Đọc phần liên quan
trước khi sửa vùng đó.

## Kiến trúc

Tổ chức theo feature, mỗi feature có `models/` `data/` `domain/` `presentation/`:

```
lib/features/study_reading/
  models/      ContentSnapshot/ContentCard (định dạng GET /content, cũng là
               cache), StudyWord, Deck, CardProgress, StudySessionRecord,
               FlagChange  — dữ liệu thuần
  data/        ContentApi (Dio, mọi route backend), LocalStore (cache nội dung,
               lịch sử, hàng đợi chờ gửi, nháp lần học — trên KeyValueStore:
               SharedPreferences thật / MemoryStore trong test), BundledContent
               (đọc assets/content.json), ConnectivityGateway
  domain/      StudyEngine (ôn trong một lượt), review_schedule (gợi ý ôn lại
               theo ngày), deck_import (đọc JSON dán từ AI) — Dart thuần
  presentation/ StudySessionViewModel (Riverpod) + study_reading_view (màn
               học: ô nhập, phím tắt, tự cuộn, ghép bố cục) + widgets/
```

`presentation/widgets/` — mỗi file một vùng màn hình, sửa vùng nào đọc file đó:

| File | Nội dung |
|---|---|
| `study_header.dart` | tiêu đề, nút Tối/Sáng, dòng trạng thái đồng bộ |
| `deck_navigation.dart` | tab nhóm, hàng nút soạn nội dung, ô chọn bộ |
| `study_card.dart` | thẻ đang hỏi: badge/cờ/menu •••, ô trả lời, phản hồi |
| `study_panels.dart` | thống kê, thanh tiến độ, nút điều khiển, màn hoàn thành/trống/lỗi |
| `hint_box.dart`, `dashed_line.dart` | chú thích trên thẻ, đường kẻ đứt bên trái thẻ |
| `answer_note.dart` | giải thích đáp án (Markdown) sau khi lộ mặt sau |
| `card_text_zoom.dart` | phóng chữ nội dung thẻ + nút "Aa" |
| `deck_editor_dialog.dart`, `edit_card_dialog.dart`, `history_sheet.dart` | hộp thoại soạn bộ/nhóm, sửa thẻ, bảng lịch sử |

Widget nhận `state` + `palette` qua tham số, gọi view model bằng
`ref.read(studySessionViewModelProvider.notifier)`. Controller/focus của ô trả
lời do `study_reading_view` giữ (phím tắt, tự cuộn, dọn ô theo `cardSerial` cần
tới) rồi truyền vào `StudyCard`.

- **`StudyEngine` là Dart thuần** — điều kiện để test thuật toán trực tiếp
  không cần widget test.
- **Engine cố tình mutable, view model phát snapshot bất biến.** Thuật toán
  xoay quanh chèn/rút thẻ khỏi hàng đợi; viết immutable vừa dài vừa chậm. Ranh
  giới là `StudySessionViewModel._snapshot()` — widget không bao giờ cầm
  `StudyEngine`.
- **Random tiêm được** (`StudyEngine(random: ...)`) để test cố định hạt giống.
- **`ContentApi` mọi lỗi đều là `ApiException`** (kể cả body sai định dạng) —
  `_syncOnce` chỉ bắt loại này; lọt lỗi khác là đồng bộ kẹt ở "đang đồng bộ".

## Giao diện

- **Dropdown chọn deck phải là controlled widget**, không dùng
  `DropdownButtonFormField`: nó giữ giá trị riêng trong `FormFieldState`, engine
  tự đổi deck (đổi nhóm, xoá thẻ) thì ô chọn lệch và Flutter ném assert.
- **`MaterialApp` luôn có `theme: buildAppTheme(...)`.** Màu *trạng thái* của
  widget Material (disabled, con trỏ, handle bôi đen, dialog, SnackBar) lấy từ
  `ThemeData`; thiếu thì thành đen-trên-đen ở chế độ tối (lỗi cũ: nút "Thẻ
  tiếp" trông trống trơn). `study_reading_view_test.dart` đo độ sáng chữ để chặn.
- **Nút có `styleFrom(foregroundColor:)` không tự có màu disabled** — resolve ra
  `null` rồi rơi xuống theme, nên màu disabled đặt ở `buildAppTheme`.
- **Phím tắt bắt ở `HardwareKeyboard`** (`_handleShortcut` trong
  `study_reading_view.dart`), không dùng `Shortcuts`/`Focus`: sau khi trả lời ô
  nhập bị vô hiệu hoá và mất focus nên không nhận được `Enter`. Handler bỏ qua
  khi route hiện tại không phải màn học (dialog, menu •••) và bỏ qua `Enter`
  thường khi chưa trả lời (để TextField chấm bài và bộ gõ Hàn chốt chữ). "Xem
  đáp án" là `Cmd+/` — **không phải `Cmd+Space`** (macOS giữ cho Spotlight/bộ gõ).
  Thẻ tự chấm (không có ô nhập): chưa lật thì `Space`/`Enter`/`Cmd+/` = Lật
  thẻ, `Cmd+Enter` = Đã thuộc; đã lật thì `1`/`→` = Nhớ, `0`/`←` = Chưa nhớ —
  cố ý không dùng `Enter` để bấm Enter hai lần không lỡ tay chấm "Nhớ".
  `Cmd+.` = nghe/tạm dừng file nghe (xem "File nghe").
- **Phóng chữ trên thẻ** (`cardZoomProvider`, nấc 85%–160%, lưu
  SharedPreferences riêng từng máy): `Cmd` + `=`/`−`/`0` hoặc nút "Aa" cạnh
  •••. Chỉ chữ *nội dung* thẻ to lên — `CardTextZoom` bọc riêng mặt
  trước/sau, gợi ý, ô nhập, dòng ✓/✕, giải thích; badge/cờ/nút giữ cỡ gốc.
  `CardTextZoom` luôn bọc kể cả 100% (đổi hình dạng cây là ô nhập bị dựng lại,
  mất focus). Bảng xem đầy đủ (bottom sheet) là route riêng nên tự bọc lại.
  Khung giải thích (`answerNoteMaxHeight`) cao theo cỡ chữ để giữ số dòng.
- **Ô nhập dọn theo `cardSerial`**, không theo đối tượng thẻ (`replaceContent`
  tạo đối tượng mới cho cùng thẻ đang hỏi). Sang thẻ tự chấm thì `unfocus()` để
  điện thoại cụp bàn phím.
- **Widget con trong thẻ key theo `cardSerial` phải kèm tên riêng**
  (`ValueKey(("hint", serial))`, `("note", serial)`): `HintBox` và `AnswerNote`
  cùng nằm trong một `Column`, trùng key thì bản release không báo lỗi mà giữ
  lại element cũ — gợi ý thẻ trước vẫn hiện ở thẻ sau.
- **Thẻ tự chấm** (`typeAnswer == false`): `StudyCard` thay ô nhập bằng
  `_FlipSide` (chưa lật: ô "chạm để lật"; lật rồi: mặt sau + đáp án phụ);
  `StudyControls` đổi "Xem đáp án" thành "Lật thẻ", lật rồi thì hàng trên là
  "✕ Chưa nhớ" / "✓ Nhớ". Tự chấm xong sang thẻ tiếp luôn, không khoá 2 giây.

## File nghe (chỉ Mac/web)

- Mỗi trường của thẻ (mặt trước/sau, gợi ý, giải thích) gắn được một MP3
  (`StudyWord.audio`, `CardAudio`). Nút ▶︎ (`AudioButton`) nằm ngay cạnh trường
  đó, **chỉ phát khi bấm**; mặt sau/giải thích chỉ hiện khi đã lộ đáp án.
  Điện thoại không hiện nút, không tải file (chưa hỗ trợ nghe).
- Phát thẳng từ `GET /audio/:id` (không cache offline); `SyncStatus.offline`
  thì nút bị tắt. `Cmd+.` phát trường đang hiện, ưu tiên mặt sau khi đã lộ
  đáp án (`visibleAudioFields`).
- Một trình phát dùng chung (`AudioPlayback`, keepAlive): bấm file khác thì
  file cũ dừng; sang thẻ khác (đổi `cardSerial`) thì dừng hẳn — gọi sau frame vì
  không được đổi provider trong lúc build. Đóng dialog sửa thẻ cũng dừng.
- `AudioPlayerGateway` bọc just_audio: `play()` của just_audio chỉ xong khi
  dừng/hết bài — **đừng await**.
- Dialog sửa thẻ: nút "Thêm file nghe" ở dòng nhãn mỗi trường → chọn MP3
  (`AudioFilePicker`, file_picker) → **tải lên ngay** → lưu thẻ chỉ gửi id. Gợi
  ý/giải thích có file nghe thì phải có chữ (nút nằm cạnh chữ).
- Quyền macOS, đừng gỡ: `files.user-selected.read-only` (chọn file trong
  sandbox) và `NSAppTransportSecurity` trong `Info.plist` (AVPlayer, khác Dio,
  chịu ATS khi tải `http://`).

## Điện thoại

- **Tự chọn bàn phím Hàn khi focus ô gõ Hàn:** bọc bằng
  `KeyboardLanguageScope(languageCode: "ko")` **và** truyền
  `hintLocales: koreanKeyboard` — cần cả hai:
  - Android: `TextField.hintLocales` (Flutter hỗ trợ sẵn, chỉ Android).
  - iOS: Flutter không hỗ trợ; `ios/Runner/AppDelegate.swift`
    (`KeyboardLanguage`) gắn `textInputMode` + `textInputContextIdentifier` vào
    class nội bộ `FlutterTextInputView`, điều khiển qua MethodChannel
    `flashcard/keyboard_language`. Identifier riêng giúp iOS trả lại bàn phím
    cũ khi rời ô.
  - **Nâng cấp Flutter thì kiểm tra** `strings Flutter.framework/Flutter | grep
    FlutterTextInputView` và engine chưa tự override hai thuộc tính kia. Class
    đổi tên thì code Swift thành no-op (không crash), chỉ mất tính năng.
  - Web không làm được: trình duyệt không cho trang đổi bàn phím.
- **Tự cuộn khi focus ô trả lời** (`_scrollForTyping`): cuộn thấp nhất mà ô
  chọn bộ từ vẫn thấy; màn quá thấp thì ưu tiên ô trả lời. Debounce 300ms chờ
  bàn phím mở xong (metrics đổi liên tục trong animation).
- **Soạn nội dung chỉ trên Mac/web** (`!isPhone`): "+ Nhóm", "✎" đổi tên nhóm,
  "+ Bộ mới", "+ Thêm từ vào bộ này", "✎ Sửa / xoá thẻ". Điện thoại chỉ còn
  ⭐/漢 trong menu •••. Trình tạo bộ nhận JSON `{"name", "words": [{front,
  back, hint?, note?, altAnswers?, typeAnswer?}]}` hoặc mảng
  trần, kể cả còn bọc trong ` ```json `; nút "Sao chép prompt tách từ" chép
  `deckExtractionPrompt`. Xem trước liệt kê từng thẻ với ô "Nhập đáp án" (tick
  sẵn theo `defaultTypeAnswer`: mặt sau ≤ 3 từ), đổi được trước khi gửi. Dialog
  sửa thẻ có checkbox "Nhập đáp án" và ô "Giải thích đáp án".
- **Giải thích đáp án** (`note`, không bắt buộc): Markdown dán từ AI, render
  bằng `flutter_markdown_plus` trong `answer_note.dart`, chỉ hiện khi đã lộ
  mặt sau (`answered || flipped`). **Không trim** ở client (thụt lề/dòng trống
  là định dạng) — server dọn hai đầu (`cleanNote`). `softLineBreak: true` để
  giữ xuống dòng đơn. Copy từ giao diện chat (không phải Markdown gốc) làm
  mất thụt lề danh sách — `nestFlattenedLists` (`domain/note_format.dart`)
  dựng lại lúc hiển thị: mục chỉ gồm chữ đậm kết thúc `:` là mục cha, các mục
  sau nó tới dòng trống thành mục con; có thụt lề thật thì bỏ qua. Đậm/tiêu đề là w600 (font chỉ bundle SemiBold). Khung
  cao tối đa `answerNoteMaxHeight`: máy tính cuộn trong khung, điện thoại cắt
  bớt + bấm mở bảng đầy đủ (giống `HintBox`, không dùng `LayoutBuilder`).

## Mạng

- **Điện thoại thật phải chạy với
  `--dart-define=API_BASE_URL=http://<IP-LAN-của-Mac>:3000`** (`ipconfig
  getifaddr en0`). Không truyền thì app gọi `localhost` — chính điện thoại — và
  luôn báo "Ngoại tuyến". Rê/giữ vào dòng trạng thái ở header để xem URL.
- Quyền mạng đã bật, đừng gỡ: macOS `com.apple.security.network.client`
  (thiếu là sandbox chặn mọi request), iOS `NSAppTransportSecurity` +
  `NSLocalNetworkUsageDescription` (server dev http trong LAN), Android
  `usesCleartextTraffic`.
- **`baseUrl` theo nền tảng** (`core/api/api_client.dart`), đừng hard-code
  `10.0.2.2` (chỉ có nghĩa trong máy ảo Android). Check `kIsWeb` trước
  `Platform.isAndroid` — gọi `Platform` trên web sẽ crash.
- Máy đã cài bản cũ còn khoá `vocab-app-state` trong SharedPreferences — app
  không đọc nữa nhưng cố ý không xoá (phòng cần cứu thay đổi chưa đồng bộ).

## Font tiếng Hàn

`frontend/assets/fonts/` — 6 file `.ttf` đóng gói sẵn (~20MB):

| File | Dùng cho |
|---|---|
| `NotoSans-Regular.ttf`, `NotoSans-SemiBold.ttf` | `GoogleFonts.notoSans()` — chữ Việt/UI |
| `NotoSans-Italic.ttf` | chú thích in nghiêng trên thẻ (`HintBox`) |
| `NotoSansKR-Regular.ttf`, `-SemiBold.ttf`, `-Bold.ttf` | `GoogleFonts.notoSansKr()` — chữ Hàn, kể cả tiêu đề |

**Vì sao bundle:** mặc định `google_fonts` tải font qua mạng ở lần đầu dùng mỗi
(family, weight) → lần mở app đầu tiên chữ Hàn hiện font dự phòng rồi layout
lại ("giật lúc khởi động"). Bundle sẵn thì `google_fonts` tìm thấy trong
`rootBundle` trước khi thử mạng (cơ chế có sẵn của package) — mượt kể cả lần
đầu, kể cả offline.

**Đã bỏ `notoSerifKr`** (~28MB, bộ chữ Hán đầy đủ, chỉ để hiện vài tiêu đề) —
mọi chỗ dùng `notoSansKr`.

**Thêm weight/`fontStyle` mới thì phải bundle file tương ứng** — nếu không lại
tải mạng đúng combo đó. `FontStyle.italic` là biến thể riêng, cần file
`-Italic` (bản đầu từng sót đúng chỗ này). Tên file phải đúng hậu tố
`{Family}-{Regular|SemiBold|Bold|Italic}.ttf`. Kiểm tra bằng
`test/bundled_fonts_test.dart`.

**File mất/hỏng thì tải lại:** `https://fonts.gstatic.com/s/a/<hash>.ttf` (hash
lấy từ `google_fonts_parts/part_n.dart` trong package):

| File | `<hash>` |
|---|---|
| `NotoSans-Regular.ttf` | `61ea1e781b9d7b10db9b4a6aa2d855cf2215c316c7cb700aeb067a0440d031e0` |
| `NotoSans-SemiBold.ttf` | `6c302f0c3ac2c7afcfde0f124337360cdceda4f28564fab69d39460e5ecb4392` |
| `NotoSans-Italic.ttf` | `9f15655bceebde7d143c5985eb8b26d73df858dd35578a65c332fd1a8bd7ebc0` |
| `NotoSansKR-Regular.ttf` | `65f278fc677a3a0128c733af662c3eb31b910c9bce81e046ccc3c6d3ede879e2` |
| `NotoSansKR-SemiBold.ttf` | `21ec9ca6ade00303740d965d4953af2af81a7ae1316d61de16ceded863394d7c` |
| `NotoSansKR-Bold.ttf` | `45f69f3abd7e355bcd9f754261c5090ab3b7e1b526c6af60a71fe7d999b35073` |
