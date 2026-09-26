/// Tiến trình Leitner của một thẻ **trong một lượt học** — không lưu lại, hết
/// lượt (đổi bộ, học lại, tắt app) là bỏ.
class CardProgress {
  CardProgress({this.box = 0, this.streak = 0, this.mastered = false});

  /// Bậc giãn cách hiện tại, dùng để tra [StudyEngine.boxOffsets].
  int box;

  /// Số lần trả lời đúng liên tiếp.
  int streak;

  bool mastered;

  CardProgress copy() =>
      CardProgress(box: box, streak: streak, mastered: mastered);
}

/// Trạng thái một lượt học của một deck.
class DeckRuntime {
  DeckRuntime({
    required this.cardState,
    required this.activeQueue,
    this.correctCount = 0,
    this.attemptedCount = 0,
    this.masteredCount = 0,
  });

  final List<CardProgress> cardState;

  /// Hàng đợi các chỉ số thẻ chờ hỏi. Thẻ đang hiển thị đã được lấy ra khỏi đây.
  final List<int> activeQueue;

  int correctCount;
  int attemptedCount;
  int masteredCount;
}
