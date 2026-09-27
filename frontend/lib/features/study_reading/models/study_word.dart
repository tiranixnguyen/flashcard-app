/// Một thẻ trong lúc học (đã làm phẳng chuỗi thẻ ngữ cảnh).
///
/// Bất biến về nội dung: sửa/xoá/thêm thẻ thì dựng lại cả danh sách rồi đưa
/// vào `StudyEngine.replaceContent`, engine tự mang tiến trình lượt học đang
/// dở sang theo [id].
class StudyWord {
  StudyWord({
    required this.id,
    required this.front,
    required this.back,
    this.hint,
    this.note,
    this.altAnswers,
    this.typeAnswer = false,
    this.isFollowUp = false,
    this.followUpIndex,
    this.impliesIndex,
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

  /// `true` nếu đây là thẻ ngữ cảnh nối tiếp một thẻ gốc.
  final bool isFollowUp;

  /// Vị trí thẻ nối tiếp kế sau trong cùng bộ, `null` nếu chuỗi kết thúc.
  /// Gán sau khi dựng xong cả bộ (xem `buildStudyCatalog`).
  int? followUpIndex;

  /// Vị trí thẻ gốc mà thẻ này hàm ý: trả lời đúng thẻ ngữ cảnh nghĩa là đã
  /// thuộc thẻ gốc, nên thẻ gốc được tính là thuộc luôn.
  final int? impliesIndex;

  bool matches(String answer) =>
      answer == back || (altAnswers?.contains(answer) ?? false);

  /// Bản sao đứng một mình cho bộ ảo — bỏ liên kết chuỗi ngữ cảnh vì chỉ số
  /// chỉ có nghĩa trong bộ gốc.
  StudyWord copyAsVirtual() => StudyWord(
    id: id,
    front: front,
    back: back,
    hint: hint,
    note: note,
    altAnswers: altAnswers,
    typeAnswer: typeAnswer,
  );
}
