import "dart:math";

import "package:flashcard_app/features/study_reading/domain/deck_import.dart";
import "package:flashcard_app/features/study_reading/domain/study_engine.dart";
import "package:flashcard_app/features/study_reading/models/card_audio.dart";
import "package:flashcard_app/features/study_reading/models/content.dart";

/// Dựng một bộ giống hệt server làm từ JSON nhập bộ: mỗi từ một thẻ, không ghi
/// `typeAnswer` thì theo `defaultTypeAnswer` (đáp án ngắn là gõ đáp án), id
/// `<deckId>-<vị trí>`. File nghe ghi thẳng như JSON server (`"backAudioId"`…).
ContentDeck contentDeck(
  String id,
  List<Map<String, dynamic>> words, {
  String groupId = "g1",
  String? name,
  int position = 0,
  Set<int> marked = const {},
  Set<int> hanja = const {},
  Set<int> passage = const {},
}) {
  final cards = <ContentCard>[];
  for (final (i, w) in words.indexed) {
    final b = w["back"] as String;
    cards.add(
      ContentCard(
        id: "$id-$i",
        position: i,
        back: b,
        front: w["front"] as String,
        hint: w["hint"] as String?,
        note: w["note"] as String?,
        altAnswers: (w["altAnswers"] as List?)?.cast<String>() ?? const [],
        typeAnswer: w["typeAnswer"] as bool? ?? defaultTypeAnswer(b),
        marked: marked.contains(i),
        hanja: hanja.contains(i),
        passage: passage.contains(i),
        audio: CardAudio.fromJson(w),
      ),
    );
  }
  return ContentDeck(
    id: id,
    groupId: groupId,
    name: name ?? "Bộ $id",
    position: position,
    cards: cards,
  );
}

ContentSnapshot contentOf(
  List<ContentDeck> decks, {
  List<ContentGroup> groups = const [
    ContentGroup(id: "g1", name: "Sep1", position: 0),
  ],
}) => ContentSnapshot(groups: groups, decks: decks);

const threeWords = [
  {"back": "학생", "front": "học sinh"},
  {"back": "선생님", "front": "giáo viên"},
  {"back": "학교", "front": "trường học"},
];

/// Engine trên nội dung cho sẵn, hạt giống cố định để thứ tự lặp lại được.
StudyEngine engineFor(ContentSnapshot content, {int seed = 42}) {
  final c = buildStudyCatalog(content);
  return StudyEngine(
    decks: c.decks,
    vocabGroups: c.vocabGroups,
    markedIds: c.markedIds,
    hanjaIds: c.hanjaIds,
    passageIds: c.passageIds,
    random: Random(seed),
  )..bootstrap();
}

/// Đưa nội dung mới vào engine đang chạy (như khi tải lại từ server).
bool replaceWith(StudyEngine e, ContentSnapshot content) {
  final c = buildStudyCatalog(content);
  return e.replaceContent(
    decks: c.decks,
    vocabGroups: c.vocabGroups,
    markedIds: c.markedIds,
    hanjaIds: c.hanjaIds,
    passageIds: c.passageIds,
  );
}
