import "../models/study_session_record.dart";

/// Khoảng cách ôn lại (ngày) sau mỗi lần học tốt liên tiếp.
const reviewIntervalsDays = [1, 3, 7, 14, 30, 60];

/// Tỉ lệ đúng tối thiểu để một lần học được tính là "tốt".
const goodAccuracy = 0.8;

enum ReviewState {
  /// Chưa từng học hết bộ này.
  neverStudied,

  /// Tới hạn hôm nay hoặc đã quá hạn.
  due,

  /// Chưa tới hạn.
  upcoming,
}

class ReviewStatus {
  const ReviewStatus({
    required this.state,
    this.dueDay,
    this.daysUntilDue = 0,
    this.lastStudiedAt,
    this.level = 0,
  });

  final ReviewState state;

  /// Ngày nên ôn (chỉ phần ngày, giờ địa phương).
  final DateTime? dueDay;

  /// Âm = quá hạn bao nhiêu ngày, 0 = hôm nay, dương = còn bao nhiêu ngày.
  final int daysUntilDue;

  /// Lần học gần nhất (kể cả lần học dở).
  final DateTime? lastStudiedAt;

  /// Số lần học tốt liên tiếp đang được tính — bậc trong [reviewIntervalsDays].
  final int level;

  /// Nhãn ngắn gắn sau tên bộ trong danh sách chọn bộ.
  String get shortLabel => switch (state) {
    ReviewState.neverStudied => "chưa học",
    ReviewState.due when daysUntilDue < 0 => "quá hạn ${-daysUntilDue} ngày",
    ReviewState.due => "nên ôn hôm nay",
    ReviewState.upcoming when daysUntilDue == 1 => "ôn lại ngày mai",
    ReviewState.upcoming => "ôn lại sau $daysUntilDue ngày",
  };
}

DateTime _day(DateTime t) {
  final local = t.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Gợi ý ôn lại một bộ từ lịch sử các lần học của nó (mọi máy gộp chung).
///
/// Quy tắc (người dùng đã chọn):
/// - Chỉ lần học **hết bộ** mới ảnh hưởng lịch; học dở thì chỉ ghi vào lịch sử.
/// - Lần hết bộ với tỉ lệ đúng ≥ 80% đúng hoặc sau ngày hẹn: lên một bậc,
///   khoảng cách 1 → 3 → 7 → 14 → 30 → 60 ngày.
/// - Ôn **trước** ngày hẹn mà vẫn tốt: giữ nguyên bậc và ngày hẹn — học sớm
///   không nên làm giãn lịch, nếu không học dồn một ngày là "nhảy" bậc liền.
/// - Tỉ lệ đúng < 80%: về bậc đầu, hẹn ôn lại sau 1 ngày.
///
/// So theo ngày lịch (giờ địa phương), không theo giờ: học lúc 23h với 7h sáng
/// hôm sau vẫn là "ngày mai".
ReviewStatus computeReviewStatus(
  Iterable<StudySessionRecord> sessionsOfDeck,
  DateTime now,
) {
  final sorted = [...sessionsOfDeck]
    ..sort((a, b) => a.endedAt.compareTo(b.endedAt));
  final lastStudiedAt = sorted.isEmpty ? null : sorted.last.endedAt;

  var level = 0;
  DateTime? dueDay;
  for (final s in sorted.where((s) => s.completed)) {
    final day = _day(s.endedAt);
    if (s.accuracy < goodAccuracy) {
      level = 0;
      dueDay = day.add(const Duration(days: 1));
    } else if (dueDay == null || !day.isBefore(dueDay)) {
      level = (level + 1).clamp(1, reviewIntervalsDays.length);
      dueDay = day.add(Duration(days: reviewIntervalsDays[level - 1]));
    }
  }

  if (dueDay == null) {
    return ReviewStatus(
      state: ReviewState.neverStudied,
      lastStudiedAt: lastStudiedAt,
    );
  }
  final daysUntil = dueDay.difference(_day(now)).inDays;
  return ReviewStatus(
    state: daysUntil <= 0 ? ReviewState.due : ReviewState.upcoming,
    dueDay: dueDay,
    daysUntilDue: daysUntil,
    lastStudiedAt: lastStudiedAt,
    level: level,
  );
}
