import "card_audio.dart";

/// Một thẻ trong lúc học.
///
/// Bất biến về nội dung: sửa/xoá/thêm thẻ thì dựng lại cả danh sách rồi đưa
/// vào `StudyEngine.replaceContent`, engine tự mang tiến trình lượt học đang
/// dở sang theo [id].
class StudyWord {
  const StudyWord({
    required this.id,
    required this.front,
    required this.back,
    this.hint,
    this.note,
    this.altAnswers,
    this.typeAnswer = false,
    this.audio = CardAudio.none,
  });

  /// Id thẻ trên server (bộ gốc: `<deckId>-<vị trí>`, vd `ds2-7`). Thẻ trong
  /// bộ ảo (⭐/漢/🔀) giữ nguyên id của thẻ gốc — nhờ vậy dấu ⭐/漢 và thao tác
  /// sửa luôn trỏ đúng thẻ thật.
  final String id;

  /// Mặt trước — câu hỏi hiện ra (thường là nghĩa tiếng Việt).
  final String front;

  /// Mặt sau — đáp án (thường là từ tiếng Hàn).
  final String back;
  final String? hint;

  /// Giải thích cho đáp án (Markdown), hiện sau khi lộ mặt sau.
  final String? note;
  final List<String>? altAnswers;

  /// `true` = gõ đáp án rồi chấm; `false` = thẻ tự chấm (lật thẻ rồi tự bấm
  /// "Nhớ"/"Chưa nhớ").
  final bool typeAnswer;

  /// File nghe theo từng trường — chỉ Mac/web phát.
  final CardAudio audio;

  bool matches(String answer) =>
      answer == back || (altAnswers?.contains(answer) ?? false);
}
