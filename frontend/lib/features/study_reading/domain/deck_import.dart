import "dart:convert";

/// Prompt dán vào claude.ai (hoặc AI bất kỳ) kèm đoạn tiếng Hàn — kết quả
/// trả về dán thẳng vào ô nhập của trình tạo bộ.
const deckExtractionPrompt = """
Tách đoạn tiếng Hàn bên dưới thành danh sách từ vựng để học (Hàn → Việt).
Chỉ trả về MỘT khối JSON, không giải thích gì thêm, đúng định dạng:
{"name": "<tên bộ ngắn gọn, tiếng Việt>", "words": [{"front": "<nghĩa tiếng Việt ngắn gọn>", "back": "<từ/biểu hiện tiếng Hàn>"}]}

Quy tắc:
- Ưu tiên bao gồm các biểu hiện, collocation, cụm từ quan trọng, thường được sử dụng, rồi mới tới từ vựng đứng đơn lẻ.
- Bỏ số, tên riêng; không lặp từ.
- Động từ/tính từ đưa về dạng nguyên thể (-다).

Đoạn văn:
""";

/// Mặt sau tối đa bấy nhiêu từ thì coi là "ngắn".
const shortAnswerMaxWords = 3;

/// JSON không ghi rõ `typeAnswer`: đáp án ngắn (≤ 3 từ) thì gõ đáp án, dài hơn
/// (câu, cụm dài — gõ lại từng chữ rất mệt) thì là thẻ tự chấm. Phải giống
/// `defaultTypeAnswer` bên backend (`wordInput.ts`).
bool defaultTypeAnswer(String back) =>
    back.trim().split(RegExp(r"\s+")).length <= shortAnswerMaxWords;

/// Kết quả đọc JSON người dùng dán vào.
class DeckImport {
  const DeckImport({this.name, this.words = const [], this.errors = const []});

  /// Tên bộ nếu JSON có trường `name`.
  final String? name;

  /// Các từ hợp lệ, đúng định dạng gửi lên server (`front`, `back`, `hint`?,
  /// `note`?, `altAnswers`?, `followUps`?). Mỗi thẻ (kể cả thẻ ngữ cảnh) luôn có sẵn
  /// `typeAnswer` — ghi rõ trong JSON, không thì theo [defaultTypeAnswer] —
  /// để trình tạo bộ hiện ô "Nhập đáp án" cho người dùng đổi trước khi gửi.
  final List<Map<String, dynamic>> words;

  /// Lỗi đọc được — có lỗi thì không cho gửi, tránh tạo bộ thiếu từ.
  final List<String> errors;

  bool get ok => errors.isEmpty && words.isNotEmpty;

  /// Số thẻ sau khi làm phẳng (tính cả thẻ ngữ cảnh).
  int get cardCount => words.fold(
    0,
    (n, w) =>
        n +
        1 +
        ((w["followUps"] as List?)?.length ?? (w["followUp"] != null ? 1 : 0)),
  );

  /// Mọi thẻ sau khi làm phẳng (thẻ gốc rồi các thẻ ngữ cảnh), theo thứ tự.
  /// Trả về chính các map trong [words] — đổi `typeAnswer` ở đây là đổi thứ
  /// sẽ gửi lên server.
  List<Map<String, dynamic>> get cards => [
    for (final w in words) ...[
      w,
      ...?(w["followUps"] as List?)?.cast<Map<String, dynamic>>(),
    ],
  ];

  /// Số thẻ gõ đáp án (còn lại là thẻ tự chấm).
  int get typeAnswerCount => cards.where((c) => c["typeAnswer"] == true).length;

  /// Mặt sau (từ tiếng Hàn) đã có trong [known] (để cảnh báo trùng, không chặn).
  List<String> duplicatesOf(Set<String> known) => [
    for (final w in words)
      if (known.contains((w["back"] as String).trim())) w["back"] as String,
  ];
}

/// Đọc JSON dạng `{"name": ..., "words": [...]}` hoặc chỉ mảng `[...]`.
/// Chấp nhận cả khi còn bọc trong khối ```json … ``` như AI hay trả về.
DeckImport parseDeckImport(String text) {
  var raw = text.trim();
  final fence = RegExp(r"```(?:json)?\s*([\s\S]*?)```").firstMatch(raw);
  if (fence != null) raw = fence.group(1)!.trim();
  if (raw.isEmpty) return const DeckImport();

  final Object? json;
  try {
    json = jsonDecode(raw);
  } on FormatException catch (e) {
    return DeckImport(errors: ["JSON không hợp lệ: ${e.message}"]);
  }

  String? name;
  Object? list;
  if (json is Map) {
    final n = json["name"];
    if (n is String && n.trim().isNotEmpty) name = n.trim();
    list = json["words"];
  } else {
    list = json;
  }
  if (list is! List) {
    return DeckImport(
      name: name,
      errors: const ["Cần một mảng từ, hoặc object có trường \"words\"."],
    );
  }
  if (list.length > 500) {
    return DeckImport(name: name, errors: const ["Tối đa 500 từ mỗi lần."]);
  }

  final errors = <String>[];
  final words = <Map<String, dynamic>>[];
  String? str(Object? v) =>
      v is String && v.trim().isNotEmpty ? v.trim() : null;
  // Giải thích là Markdown: giữ nguyên thụt lề/xuống dòng, server tự dọn hai
  // đầu (cleanNote) — trim ở đây sẽ phá khối code thụt lề ở dòng đầu.
  String? note(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
  bool typeAnswerOf(Map<dynamic, dynamic> m, String back) =>
      m["typeAnswer"] is bool
      ? m["typeAnswer"] as bool
      : defaultTypeAnswer(back);

  for (var i = 0; i < list.length; i++) {
    final w = list[i];
    final label = "Từ thứ ${i + 1}";
    if (w is! Map) {
      errors.add("$label: không phải object.");
      continue;
    }
    final front = str(w["front"]);
    final back = str(w["back"]);
    if (front == null || back == null) {
      errors.add("$label: thiếu \"front\" hoặc \"back\".");
      continue;
    }
    final out = <String, dynamic>{
      "front": front,
      "back": back,
      "typeAnswer": typeAnswerOf(w, back),
    };
    if (str(w["hint"]) case final hint?) out["hint"] = hint;
    if (note(w["note"]) case final n?) out["note"] = n;
    if (w["altAnswers"] case final List alts) {
      final clean = [for (final a in alts) ?str(a)];
      if (clean.isNotEmpty) out["altAnswers"] = clean;
    }
    final chain = w["followUps"] ?? w["followUp"];
    if (chain != null) {
      final items = chain is List ? chain : [chain];
      final ups = <Map<String, dynamic>>[];
      for (final f in items) {
        final fFront = f is Map ? str(f["front"]) : null;
        if (fFront == null) {
          errors.add("$label: thẻ ngữ cảnh thiếu \"front\".");
          continue;
        }
        // Thiếu `back` thì mượn của thẻ gốc (server cũng làm vậy).
        final fBack = str((f as Map)["back"]);
        ups.add({
          "front": fFront,
          "back": ?fBack,
          "hint": ?str(f["hint"]),
          "note": ?note(f["note"]),
          "typeAnswer": typeAnswerOf(f, fBack ?? back),
        });
      }
      if (ups.isNotEmpty) out["followUps"] = ups;
    }
    words.add(out);
  }
  return DeckImport(name: name, words: words, errors: errors);
}
