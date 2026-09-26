import "package:flashcard_app/features/study_reading/domain/review_schedule.dart";
import "package:flashcard_app/features/study_reading/models/study_session_record.dart";
import "package:flutter_test/flutter_test.dart";

var _n = 0;

/// Một lần học kết thúc lúc 20h ngày [day] (giờ địa phương).
StudySessionRecord session(
  DateTime day, {
  int attempted = 10,
  int correct = 10,
  bool completed = true,
}) {
  final end = DateTime(day.year, day.month, day.day, 20);
  return StudySessionRecord(
    id: "s${_n++}",
    deckId: "d1",
    device: "ios",
    startedAt: end.subtract(const Duration(minutes: 10)),
    endedAt: end,
    attempted: attempted,
    correct: correct,
    masteredCount: 5,
    totalCards: 5,
    completed: completed,
  );
}

final d1 = DateTime(2026, 9, 1);
DateTime day(int offset) => d1.add(Duration(days: offset));

void main() {
  test("chưa học hết lần nào -> 'chưa học', kể cả khi có lần học dở", () {
    final r = computeReviewStatus([session(d1, completed: false)], day(0));
    expect(r.state, ReviewState.neverStudied);
    expect(r.shortLabel, "chưa học");
    expect(r.lastStudiedAt, isNotNull);
  });

  test("lần tốt đầu tiên -> ôn lại sau 1 ngày", () {
    final r = computeReviewStatus([session(d1)], day(0));
    expect(r.state, ReviewState.upcoming);
    expect(r.dueDay, day(1));
    expect(r.level, 1);
    expect(r.shortLabel, "ôn lại ngày mai");
  });

  test("ôn đúng hẹn liên tục -> giãn 1 → 3 → 7 → 14 → 30 → 60 ngày", () {
    final sessions = <StudySessionRecord>[];
    var t = 0;
    final gaps = <int>[];
    for (var i = 0; i < 7; i++) {
      sessions.add(session(day(t)));
      final r = computeReviewStatus(sessions, day(t));
      gaps.add(r.daysUntilDue);
      t += r.daysUntilDue; // ôn đúng ngày hẹn
    }
    expect(gaps, [1, 3, 7, 14, 30, 60, 60]); // dừng ở bậc cuối
  });

  test("tỉ lệ đúng < 80% -> về bậc đầu, hẹn ngày mai", () {
    final r = computeReviewStatus([
      session(day(0)),
      session(day(1)),
      session(day(4), attempted: 10, correct: 7),
    ], day(4));
    expect(r.level, 0);
    expect(r.dueDay, day(5));
  });

  test("đúng 80% vẫn tính là tốt", () {
    final r = computeReviewStatus([
      session(d1, attempted: 10, correct: 8),
    ], day(0));
    expect(r.level, 1);
  });

  test("ôn sớm trước hẹn mà vẫn tốt -> giữ nguyên hẹn, không nhảy bậc", () {
    final r = computeReviewStatus([
      session(day(0)),
      session(day(1)), // tới hạn -> bậc 2, hẹn +3 = ngày 4
      session(day(2)), // sớm
      session(day(3)), // sớm
    ], day(3));
    expect(r.level, 2);
    expect(r.dueDay, day(4));
  });

  test("ôn sớm mà kém thì vẫn tụt về bậc đầu", () {
    final r = computeReviewStatus([
      session(day(0)),
      session(day(1)),
      session(day(2), correct: 5),
    ], day(2));
    expect(r.level, 0);
    expect(r.dueDay, day(3));
  });

  test("lần học dở không ảnh hưởng lịch", () {
    final base = [session(day(0))];
    final withPartial = [
      ...base,
      session(day(1), correct: 1, completed: false),
    ];
    expect(
      computeReviewStatus(withPartial, day(1)).dueDay,
      computeReviewStatus(base, day(1)).dueDay,
    );
  });

  test("quá hạn -> đếm số ngày quá hạn", () {
    final r = computeReviewStatus([session(d1)], day(4));
    expect(r.state, ReviewState.due);
    expect(r.daysUntilDue, -3);
    expect(r.shortLabel, "quá hạn 3 ngày");
  });

  test(
    "đúng ngày hẹn -> 'nên ôn hôm nay', so theo ngày chứ không theo giờ",
    () {
      // Học 20h hôm trước, mở app 7h sáng hôm sau (chưa đủ 24 giờ).
      final r = computeReviewStatus([session(d1)], DateTime(2026, 9, 2, 7));
      expect(r.state, ReviewState.due);
      expect(r.shortLabel, "nên ôn hôm nay");
    },
  );

  test("thứ tự đầu vào không quan trọng", () {
    final a = session(day(0));
    final b = session(day(1));
    expect(
      computeReviewStatus([b, a], day(1)).dueDay,
      computeReviewStatus([a, b], day(1)).dueDay,
    );
  });

  test("chưa trả lời lần nào (chỉ bấm Đã thuộc) coi như 100%", () {
    final r = computeReviewStatus([
      session(d1, attempted: 0, correct: 0),
    ], day(0));
    expect(r.level, 1);
  });

  test("id lần học: 32 ký tự hex, không trùng", () {
    final ids = {for (var i = 0; i < 1000; i++) newSessionId()};
    expect(ids, hasLength(1000));
    expect(ids.first, matches(RegExp(r"^[0-9a-f]{32}$")));
  });
}
