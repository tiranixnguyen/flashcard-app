# Thuật toán ôn tập

Mô tả thuật toán trong `frontend/lib/features/study_reading/domain/study_engine.dart`,
port từ app HTML gốc. Đọc file này trước khi chỉnh bất kỳ hằng số nào.

## Mô hình: Leitner trong một lượt học

Việc ôn từng thẻ diễn ra **trong một lượt học**: thẻ trả lời sai quay lại sau
vài thẻ, thẻ trả lời đúng bị đẩy ra xa dần, cho đến khi mọi thẻ đều "thuộc".
Lịch theo ngày chỉ tồn tại ở mức **cả bộ** — xem "Gợi ý ôn lại" bên dưới.

Mỗi thẻ có `CardProgress { box, streak, mastered }` — **chỉ sống trong lượt
học**, không lưu. Mỗi lần vào một bộ (đổi bộ, đổi nhóm, học lại, mở lại app)
là một lượt mới từ đầu.

| Hằng số | Giá trị | Ý nghĩa |
|---|---|---|
| `masteryStreak` | 3 | Đúng 3 lần liên tiếp → thẻ được coi là đã thuộc |
| `wrongOffset` | 2 | Trả lời sai → chèn lại vào hàng đợi sau 2 thẻ |
| `boxOffsets` | `[3, 5, 9, 15]` | Trả lời đúng → chèn lại sau `boxOffsets[box]` thẻ |

### Trả lời đúng

```
streak++
box = min(box + 1, boxOffsets.length - 1)
nếu streak >= 3  → mastered = true, rút khỏi hàng đợi
ngược lại        → chèn lại ở vị trí boxOffsets[box]
```

### Trả lời sai

```
box = 0
streak = 0
chèn lại ở vị trí wrongOffset (2)
```

Đặt lại `box` về 0 chứ không chỉ giảm một bậc: sai nghĩa là chưa nhớ, nên phải
gặp lại sớm và leo lại từ đầu.

## Hàng đợi

`DeckRuntime.activeQueue` là danh sách chỉ số thẻ chờ hỏi.

**Thẻ đang hiển thị đã bị lấy ra khỏi hàng đợi** ngay lúc `loadCard()`. Hệ quả:
nếu người học đổi deck/đổi nhóm khi chưa trả lời, thẻ đó phải được trả lại hàng
đợi — nếu không nó biến mất khỏi lượt học. Đó là việc của
`_returnCurrentCardIfUnanswered()`.

Nếu hàng đợi rỗng nhưng chưa thuộc hết, `loadCard()` nạp lại toàn bộ thẻ chưa
thuộc thay vì báo hoàn thành. Đây là lưới an toàn cho trường hợp có thẻ bị lệch
khỏi hàng đợi do sửa/xoá.

## Thẻ ngữ cảnh (follow-up)

Một số mục trong `decks.json` có `followUp` — một câu dùng chính từ đó trong ngữ
cảnh. Lúc nạp, `expandWords()` **làm phẳng** chuỗi này vào cùng một mảng:

- thẻ gốc → `followUpIndex` trỏ tới thẻ ngữ cảnh kế tiếp
- thẻ ngữ cảnh → `impliesIndex` trỏ ngược về thẻ gốc, `isFollowUp = true`

Hai quy tắc đi kèm:

1. Trả lời xong thẻ gốc, thẻ ngữ cảnh được **đẩy lên đầu hàng đợi** để hỏi ngay
   (`_forceFollowUpIfAny`) — học từ trong ngữ cảnh liền mạch mới có tác dụng.
2. Trả lời **đúng** thẻ ngữ cảnh → thẻ gốc được đánh dấu thuộc luôn
   (`_masterCardAt(impliesIndex)`): dùng được từ trong câu thì đã thuộc từ đó.

Xoá một thẻ gốc sẽ xoá cả chuỗi ngữ cảnh nối sau nó — thẻ con mồ côi không còn
gì để bám vào.

## "Thật ra tôi viết đúng"

Người học gõ sai chính tả nhưng thực sự biết từ. `overrideAsCorrect()`:

1. Gỡ **mọi** bản ghi của thẻ khỏi hàng đợi (nhánh "sai" vừa chèn vào).
2. Khôi phục `box`/`streak` về ảnh chụp trước khi trả lời (`_answerSnapshot`).
3. `correctCount++`, rồi chạy lại `_applySchedule(true)`.

Nghĩa là streak nối tiếp đúng chỗ nó đang ở, không khởi động lại từ 0.

Nút này (nhãn trên UI: "Đã trả lời đúng?"; bấm xong hiện "✓ 맞아 — <đáp án>"
để vẫn đối chiếu được chính tả) **chỉ hiện sau khi gõ sai**, không hiện sau
khi bấm "Xem đáp án" — lúc đó người học chưa hề trả lời nên không có gì để
sửa lại.

## Thẻ tự chấm (`typeAnswer == false`)

Mỗi thẻ có `front` (mặt trước, câu hỏi) và `back` (mặt sau, đáp án), cùng
`typeAnswer`: `true` = gõ đáp án như trên; `false` = **thẻ tự chấm** — kiểu
lật thẻ của Anki. Thẻ mới mặc định là tự chấm; nhập bộ mà JSON không ghi rõ
thì `back` ≤ 3 từ (tách theo khoảng trắng) là gõ đáp án — câu/cụm dài gõ lại
từng chữ rất mệt (`defaultTypeAnswer`, có bản giống hệt ở `wordInput.ts`;
migration `card_front_back_type_answer` áp cùng quy tắc cho thẻ đã có).

1. `flipCard()` — lật sang mặt sau. **Không** phải là trả lời: chưa tính
   đúng/sai, không đụng hàng đợi (khác "Xem đáp án" của thẻ gõ, tính là sai).
2. `gradeSelf(remembered:)` — chỉ sau khi lật. "Nhớ" đi đúng nhánh gõ đúng,
   "Chưa nhớ" đi đúng nhánh gõ sai: cùng `_applySchedule`, cùng cách tính tỉ lệ
   đúng cho gợi ý ôn lại, thẻ ngữ cảnh "Nhớ" vẫn kéo thẻ gốc thuộc theo. Không
   có "Đã trả lời đúng?" (tự chấm rồi). View model sang thẻ tiếp luôn, không
   khoá 2 giây (mặt sau đã hiện trước khi chấm).
3. "Đã thuộc" vẫn dùng được trước khi chấm. `checkAnswer`/`revealAnswer` bỏ
   qua thẻ tự chấm; `flipCard`/`gradeSelf` bỏ qua thẻ gõ đáp án.

Cờ `flipped` về `false` mỗi lần `loadCard()`; `replaceContent` giữ thẻ đang
hỏi nên giữ luôn trạng thái lật.

## Deck ảo

Ba deck dựng động, không có trên server, không ghi lịch sử học:

| id | Nội dung |
|---|---|
| `marked` | ⭐ các thẻ được đánh dấu khó nhớ |
| `hanja` | 漢 các thẻ được đánh dấu là từ Hán Hàn |
| `random20` | 🔀 20 thẻ gốc ngẫu nhiên, rút lại mỗi lần mở |

Thẻ trong deck ảo là bản sao **giữ nguyên `id` của thẻ gốc** — mọi thao tác
đánh dấu, sửa, xoá đều đi theo id nên luôn trúng thẻ thật.

Cờ đánh dấu chỉ tính trong phạm vi nhóm đang học (`visibleDecks`): đang ở Sep1
thì không thấy từ đã đánh dấu ở Sep2.

Bỏ ⭐/漢 ngay trong deck ⭐/漢 tương ứng: thẻ vẫn hiện tới khi sang thẻ tiếp (xem
nốt đáp án, bấm nhầm thì bấm lại), rồi rơi hẳn khỏi lượt và tổng số thẻ giảm
theo (`_pruneUnflagged`, chạy lúc nạp thẻ mới).

## Nội dung đổi giữa lượt học (`replaceContent`)

Nội dung có thể đổi khi đang học: tải lại từ server (sửa trên máy khác), hoặc
sửa/xoá/thêm từ trên Mac/web. Engine nhận danh sách bộ mới và **mang tiến trình
lượt đang học sang theo id thẻ**: thẻ còn thì giữ box/streak/đã thuộc và vị trí
trong hàng đợi, thẻ bị xoá rơi ra, thẻ mới thêm vào cuối hàng đợi. Thẻ đang hỏi
vẫn còn thì giữ nguyên (không dọn ô nhập — UI dựa vào `cardSerial`, không dựa
vào đối tượng thẻ). Bộ đang học biến mất thì mở bộ đầu tiên của nhóm.

## Gợi ý ôn lại (`review_schedule.dart`)

Mỗi lần học một bộ thật (không phải bộ ảo) được ghi thành một
`StudySessionRecord`: máy, lúc bắt đầu/kết thúc, số lần trả lời/đúng, số thẻ đã
thuộc, và **hết bộ hay bỏ dở**. Lần học bắt đầu ở câu trả lời đầu tiên (mở bộ
rồi đổi đi ngay thì không ghi gì); kết thúc khi thuộc hết bộ (hoàn thành), hoặc
khi đổi bộ/đổi nhóm/học lại/tắt app (học dở — bản nháp lưu sau mỗi câu, lần mở
app sau chốt lại với giờ kết thúc = câu trả lời cuối).

Lịch sử của **mọi máy** được gộp chung rồi tính gợi ý bằng một hàm thuần:

| Tình huống | Kết quả |
|---|---|
| Chưa có lần học **hết bộ** nào | "chưa học" |
| Hết bộ, tỉ lệ đúng ≥ 80%, **đúng hoặc sau** ngày hẹn | lên một bậc: hẹn sau 1 → 3 → 7 → 14 → 30 → 60 ngày |
| Hết bộ, ≥ 80%, **trước** ngày hẹn | giữ nguyên bậc và ngày hẹn (học dồn không làm giãn lịch) |
| Hết bộ, < 80% | về bậc đầu, hẹn ngày mai |
| Học dở | chỉ ghi lịch sử, không ảnh hưởng lịch |

Tỉ lệ đúng = `correct / attempted`, tính cả những lần hỏi lại cùng một thẻ
("Xem đáp án" và "Chưa nhớ" tính là sai; chỉ bấm "Đã thuộc" mà không gõ câu
nào = 100%). So
theo **ngày lịch** giờ địa phương, không theo số giờ: học 23h rồi mở lúc 7h sáng
hôm sau vẫn là "ngày mai".

## Đồng bộ với backend

Server là nguồn đúng cho **nội dung** (`Group`/`Deck`/`Card`) và **lịch sử học**
(`StudySession`). App không gửi snapshot trạng thái nữa:

- **Nội dung** tải bằng `GET /content`, cache trên máy. Tạo/sửa (nhóm, bộ, thẻ)
  chỉ làm trên Mac/web, **cần có mạng**: gọi server trước, thành công mới áp
  vào máy.
- **⭐/漢** dùng được mọi máy, kể cả offline: đổi ngay trên máy, xếp vào hàng
  đợi `FlagChange { cardId, changedAt }`. Server giữ `markedChangedAt`/
  `hanjaChangedAt` riêng từng cờ và chỉ nhận thay đổi mới hơn — gửi trễ không
  đè lần bấm mới hơn ở máy khác.
- **Lần học** chỉ thêm, không sửa; `id` do máy sinh (128 bit ngẫu nhiên) nên gửi
  lại bao nhiêu lần vẫn chỉ ra một bản ghi, hai máy học cùng lúc không đè nhau.
  Bộ đã bị xoá thì server bỏ qua lần học của nó thay vì làm hỏng cả lô.

**Lúc mở app** (`StudySessionViewModel.build()`): nội dung cache trên máy →
không có thì `assets/content.json` → học được ngay; nháp lần học còn sót (tắt
app giữa chừng) được chốt thành "học dở"; rồi `syncNow()` chạy nền: gửi hàng
đợi → tải `/content` (áp lại ⭐/漢 còn chờ lên trên) → tải `/sessions`. Cũng
chạy lại khi có mạng trở lại (`ConnectivityGateway.onReconnected`), sau mỗi lần
học xong và mỗi lần bấm ⭐/漢. Không bao giờ ném lỗi — chỉ đổi `SyncStatus` ở
header; không chạy chồng (có yêu cầu mới lúc đang chạy thì chạy thêm một vòng).

Mô hình `Card` SM-2 cũ (`easeFactor`, `interval`, `nextReviewAt`) đã bỏ; bảng
`SyncState` (snapshot kiểu cũ) chỉ còn để script `import-content` đọc một lần,
có thể xoá khi không cần nữa.
