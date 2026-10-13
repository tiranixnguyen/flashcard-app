import "dart:math";

final _secureRandom = Random.secure();

/// Id ngẫu nhiên 128 bit dạng hex — do máy sinh để gửi lại nhiều lần không
/// tạo bản ghi trùng.
String newSessionId() => [
  for (var i = 0; i < 16; i++)
    _secureRandom.nextInt(256).toRadixString(16).padLeft(2, "0"),
].join();

/// Một lần học một bộ, trên bất kỳ máy nào — khớp bảng `StudySession` trên
/// server. Chỉ thêm, không sửa; `id` do máy sinh nên gửi lại nhiều lần vẫn chỉ
/// ra một bản ghi.
class StudySessionRecord {
  const StudySessionRecord({
    required this.id,
    required this.deckId,
    required this.device,
    required this.startedAt,
    required this.endedAt,
    required this.attempted,
    required this.correct,
    required this.masteredCount,
    required this.totalCards,
    required this.completed,
  });

  final String id;
  final String deckId;

  /// "ios" | "android" | "macos" | "web" | … — chỉ để hiển thị lịch sử.
  final String device;
  final DateTime startedAt;
  final DateTime endedAt;

  /// Số lần trả lời (kể cả hỏi lại cùng một thẻ) và số lần đúng.
  final int attempted;
  final int correct;
  final int masteredCount;
  final int totalCards;

  /// Học hết bộ (mọi thẻ đều thuộc) hay bỏ dở giữa chừng.
  final bool completed;

  /// Tỉ lệ đúng; chưa trả lời lần nào (chỉ bấm "Đã thuộc") coi như 100%.
  double get accuracy => attempted == 0 ? 1 : correct / attempted;

  factory StudySessionRecord.fromJson(Map<String, dynamic> json) =>
      StudySessionRecord(
        id: json["id"] as String,
        deckId: json["deckId"] as String,
        device: json["device"] as String,
        startedAt: DateTime.parse(json["startedAt"] as String),
        endedAt: DateTime.parse(json["endedAt"] as String),
        attempted: json["attempted"] as int,
        correct: json["correct"] as int,
        masteredCount: json["masteredCount"] as int,
        totalCards: json["totalCards"] as int,
        completed: json["completed"] as bool,
      );

  Map<String, dynamic> toJson() => {
    "id": id,
    "deckId": deckId,
    "device": device,
    "startedAt": startedAt.toUtc().toIso8601String(),
    "endedAt": endedAt.toUtc().toIso8601String(),
    "attempted": attempted,
    "correct": correct,
    "masteredCount": masteredCount,
    "totalCards": totalCards,
    "completed": completed,
  };

  StudySessionRecord copyWith({
    DateTime? endedAt,
    int? attempted,
    int? correct,
    int? masteredCount,
    int? totalCards,
    bool? completed,
  }) => StudySessionRecord(
    id: id,
    deckId: deckId,
    device: device,
    startedAt: startedAt,
    endedAt: endedAt ?? this.endedAt,
    attempted: attempted ?? this.attempted,
    correct: correct ?? this.correct,
    masteredCount: masteredCount ?? this.masteredCount,
    totalCards: totalCards ?? this.totalCards,
    completed: completed ?? this.completed,
  );
}

/// Một lần bật/tắt ⭐/漢/📖 chờ gửi lên server. `changedAt` là lúc bấm — server
/// lấy lần bấm muộn nhất, nên gửi trễ (offline) vẫn không đè lần mới hơn.
class FlagChange {
  const FlagChange({
    required this.cardId,
    required this.changedAt,
    this.marked,
    this.hanja,
    this.passage,
  });

  final String cardId;
  final DateTime changedAt;
  final bool? marked;
  final bool? hanja;
  final bool? passage;

  factory FlagChange.fromJson(Map<String, dynamic> json) => FlagChange(
    cardId: json["cardId"] as String,
    changedAt: DateTime.parse(json["changedAt"] as String),
    marked: json["marked"] as bool?,
    hanja: json["hanja"] as bool?,
    passage: json["passage"] as bool?,
  );

  Map<String, dynamic> toJson() => {
    "cardId": cardId,
    "changedAt": changedAt.toUtc().toIso8601String(),
    if (marked != null) "marked": marked,
    if (hanja != null) "hanja": hanja,
    if (passage != null) "passage": passage,
  };
}
