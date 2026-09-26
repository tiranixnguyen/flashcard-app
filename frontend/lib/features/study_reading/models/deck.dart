import "study_word.dart";

/// Nhóm bộ từ (Sep1/Sep2/… hoặc nhóm người học tự tạo trên Mac/web).
class VocabGroup {
  const VocabGroup({required this.id, required this.name});

  final String id;
  final String name;
}

class Deck {
  Deck({
    required this.id,
    required this.name,
    required this.words,
    this.group,
    this.isVirtual = false,
  });

  final String id;
  final String name;
  final String? group;

  /// Deck ảo (⭐ Từ khó nhớ, 漢 Hán Hàn, 🔀 ngẫu nhiên) được dựng động từ các
  /// deck gốc; không có trên server và không ghi lịch sử học.
  final bool isVirtual;

  final List<StudyWord> words;
}
