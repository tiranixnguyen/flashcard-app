import "study_word.dart";

/// Nhóm bộ từ (Sep1/Sep2/… hoặc nhóm người học tự tạo trên Mac/web).
class VocabGroup {
  const VocabGroup({required this.id, required this.name});

  final String id;
  final String name;
}

/// Loại bộ từ (kỹ năng). [key] là giá trị lưu trên server/cache, [label] là
/// nhãn hiển thị.
enum DeckType {
  listening("듣기"),
  speaking("말하기"),
  reading("읽기"),
  writing("쓰기"),
  grammar("문법");

  const DeckType(this.label);

  final String label;

  String get key => name;

  /// Giá trị lạ (server mới hơn app) hoặc thiếu → `null`, coi như chưa phân loại.
  static DeckType? fromKey(Object? key) =>
      values.where((t) => t.key == key).firstOrNull;
}

/// Tài liệu (giáo trình) bộ từ lấy ra. [key] là giá trị lưu trên server/cache,
/// [label] là nhãn hiển thị.
enum DeckSource {
  snu3a("SNU 3A"),
  snu3b("SNU 3B"),
  snu4a("SNU 4A"),
  snu4b("SNU 4B"),
  thth3("THTH 3"),
  thth4("THTH 4");

  const DeckSource(this.label);

  final String label;

  String get key => name;

  /// Giá trị lạ (server mới hơn app) hoặc thiếu → `null`, coi như chưa chọn.
  static DeckSource? fromKey(Object? key) =>
      values.where((s) => s.key == key).firstOrNull;
}

class Deck {
  Deck({
    required this.id,
    required this.name,
    required this.words,
    this.group,
    this.type,
    this.source,
    this.description,
    this.isVirtual = false,
  });

  final String id;
  final String name;
  final String? group;

  /// Chỉ bộ thật mới có loại; `null` = chưa phân loại.
  final DeckType? type;

  /// Tài liệu (chỉ bộ thật); `null` = chưa chọn.
  final DeckSource? source;

  /// Mô tả ngắn (chỉ bộ thật), có thể chứa link `http(s)://`.
  final String? description;

  /// Deck ảo (⭐ Từ khó nhớ, 漢 Hán Hàn, 📖 Đoạn văn ngắn, 🔀 ngẫu nhiên) được dựng động từ các
  /// deck gốc; không có trên server và không ghi lịch sử học.
  final bool isVirtual;

  final List<StudyWord> words;
}
