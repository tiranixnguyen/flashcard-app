import "dart:math";

import "package:flashcard_app/features/study_reading/domain/study_engine.dart";
import "package:flashcard_app/features/study_reading/models/content.dart";

/// Dựng một bộ giống hệt server làm từ JSON nhập bộ: thẻ gốc rồi tới các thẻ
/// ngữ cảnh (`followUp`/`followUps`, thiếu `kr` thì mượn của thẻ gốc), id
/// `<deckId>-<vị trí>`, thẻ ngữ cảnh trỏ `parentId` về thẻ gốc.
ContentDeck contentDeck(
  String id,
  List<Map<String, dynamic>> words, {
  String groupId = "g1",
  String? name,
  int position = 0,
  Set<int> marked = const {},
  Set<int> hanja = const {},
}) {
  final cards = <ContentCard>[];
  ContentCard card(Map<String, dynamic> w, {String? parentId, String? kr}) {
    final i = cards.length;
    return ContentCard(
      id: "$id-$i",
      position: i,
      parentId: parentId,
      kr: (w["kr"] as String?) ?? kr!,
      vi: w["vi"] as String,
      hint: w["hint"] as String?,
      altAnswers: (w["altAnswers"] as List?)?.cast<String>() ?? const [],
      marked: marked.contains(i),
      hanja: hanja.contains(i),
    );
  }

  for (final w in words) {
    final parent = card(w);
    cards.add(parent);
    final chain = [
      ...?(w["followUps"] as List?)?.cast<Map<String, dynamic>>(),
      if (w["followUps"] == null && w["followUp"] != null)
        w["followUp"] as Map<String, dynamic>,
    ];
    for (final f in chain) {
      cards.add(card(f, parentId: parent.id, kr: parent.kr));
    }
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
  {"kr": "학생", "vi": "học sinh"},
  {"kr": "선생님", "vi": "giáo viên"},
  {"kr": "학교", "vi": "trường học"},
];

/// Engine trên nội dung cho sẵn, hạt giống cố định để thứ tự lặp lại được.
StudyEngine engineFor(ContentSnapshot content, {int seed = 42}) {
  final c = buildStudyCatalog(content);
  return StudyEngine(
    decks: c.decks,
    vocabGroups: c.vocabGroups,
    markedIds: c.markedIds,
    hanjaIds: c.hanjaIds,
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
  );
}
