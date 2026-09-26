import "dart:convert";

/// Prompt dán vào claude.ai (hoặc AI bất kỳ) kèm đoạn tiếng Hàn — kết quả
/// trả về dán thẳng vào ô nhập của trình tạo bộ.
const deckExtractionPrompt = """
Tách đoạn tiếng Hàn bên dưới thành danh sách từ vựng để học (Hàn → Việt).
Chỉ trả về MỘT khối JSON, không giải thích gì thêm, đúng định dạng:
{"name": "<tên bộ ngắn gọn, tiếng Việt>", "words": [{"kr": "<từ/biểu hiện tiếng Hàn>", "vi": "<nghĩa tiếng Việt ngắn gọn>"}]}

Quy tắc:
- Ưu tiên bao gồm các biểu hiện, collocation, cụm từ quan trọng, thường được sử dụng, rồi mới tới từ vựng đứng đơn lẻ.
- Bỏ số, tên riêng; không lặp từ.
- Động từ/tính từ đưa về dạng nguyên thể (-다).

Đoạn văn:
""";

/// Kết quả đọc JSON người dùng dán vào.
class DeckImport {
  const DeckImport({this.name, this.words = const [], this.errors = const []});

  /// Tên bộ nếu JSON có trường `name`.
  final String? name;

  /// Các từ hợp lệ, đúng định dạng gửi lên server (`kr`, `vi`, `hint`?,
  /// `altAnswers`?, `followUp`/`followUps`?).
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

  /// Từ tiếng Hàn đã có trong [known] (để cảnh báo trùng, không chặn).
  List<String> duplicatesOf(Set<String> known) => [
    for (final w in words)
      if (known.contains((w["kr"] as String).trim())) w["kr"] as String,
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

  for (var i = 0; i < list.length; i++) {
    final w = list[i];
    final label = "Từ thứ ${i + 1}";
    if (w is! Map) {
      errors.add("$label: không phải object.");
      continue;
    }
    final kr = str(w["kr"]);
    final vi = str(w["vi"]);
    if (kr == null || vi == null) {
      errors.add("$label: thiếu \"kr\" hoặc \"vi\".");
      continue;
    }
    final out = <String, dynamic>{"kr": kr, "vi": vi};
    if (str(w["hint"]) case final hint?) out["hint"] = hint;
    if (w["altAnswers"] case final List alts) {
      final clean = [for (final a in alts) ?str(a)];
      if (clean.isNotEmpty) out["altAnswers"] = clean;
    }
    final chain = w["followUps"] ?? w["followUp"];
    if (chain != null) {
      final items = chain is List ? chain : [chain];
      final ups = <Map<String, dynamic>>[];
      for (final f in items) {
        final fvi = f is Map ? str(f["vi"]) : null;
        if (fvi == null) {
          errors.add("$label: thẻ ngữ cảnh thiếu \"vi\".");
          continue;
        }
        ups.add({
          "vi": fvi,
          "kr": ?str((f as Map)["kr"]),
          "hint": ?str(f["hint"]),
        });
      }
      if (ups.isNotEmpty) out["followUps"] = ups;
    }
    words.add(out);
  }
  return DeckImport(name: name, words: words, errors: errors);
}
