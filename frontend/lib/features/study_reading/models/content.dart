import "card_audio.dart";
import "deck.dart";
import "study_word.dart";

/// Nội dung học lấy từ server (`GET /content`), cũng là định dạng cache trên
/// máy. Server là nguồn đúng; app chỉ sửa bản sao cục bộ khi server đã nhận
/// (tạo/sửa trên Mac/web) hoặc khi bật/tắt ⭐/漢 (gửi dần qua hàng đợi).
class ContentSnapshot {
  const ContentSnapshot({required this.groups, required this.decks});

  final List<ContentGroup> groups;
  final List<ContentDeck> decks;

  factory ContentSnapshot.fromJson(Map<String, dynamic> json) =>
      ContentSnapshot(
        groups: (json["groups"] as List)
            .map((g) => ContentGroup.fromJson(g as Map<String, dynamic>))
            .toList(),
        decks: (json["decks"] as List)
            .map((d) => ContentDeck.fromJson(d as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    "groups": [for (final g in groups) g.toJson()],
    "decks": [for (final d in decks) d.toJson()],
  };

  ContentSnapshot copyWith({
    List<ContentGroup>? groups,
    List<ContentDeck>? decks,
  }) => ContentSnapshot(
    groups: groups ?? this.groups,
    decks: decks ?? this.decks,
  );

  /// Thay (hoặc thêm) một nhóm theo id.
  ContentSnapshot upsertGroup(ContentGroup group) {
    final exists = groups.any((g) => g.id == group.id);
    return copyWith(
      groups: exists
          ? [for (final g in groups) g.id == group.id ? group : g]
          : [...groups, group],
    );
  }

  /// Thay (hoặc thêm) một bộ theo id.
  ContentSnapshot upsertDeck(ContentDeck deck) {
    final exists = decks.any((d) => d.id == deck.id);
    return copyWith(
      decks: exists
          ? [for (final d in decks) d.id == deck.id ? deck : d]
          : [...decks, deck],
    );
  }

  /// Sửa một thẻ ở bất kỳ bộ nào.
  ContentSnapshot updateCard(
    String cardId,
    ContentCard Function(ContentCard) update,
  ) => copyWith(
    decks: [
      for (final d in decks)
        d.cards.any((c) => c.id == cardId)
            ? d.copyWith(
                cards: [
                  for (final c in d.cards) c.id == cardId ? update(c) : c,
                ],
              )
            : d,
    ],
  );

  /// Xoá một thẻ.
  ContentSnapshot removeCard(String cardId) => copyWith(
    decks: [
      for (final d in decks)
        d.copyWith(
          cards: [
            for (final c in d.cards)
              if (c.id != cardId) c,
          ],
        ),
    ],
  );

  /// Mọi mặt sau (từ tiếng Hàn) đang có — để báo trùng khi tạo bộ mới.
  Set<String> get allKorean => {
    for (final d in decks)
      for (final c in d.cards) c.back.trim(),
  };
}

class ContentGroup {
  const ContentGroup({
    required this.id,
    required this.name,
    required this.position,
  });

  final String id;
  final String name;
  final int position;

  factory ContentGroup.fromJson(Map<String, dynamic> json) => ContentGroup(
    id: json["id"] as String,
    name: json["name"] as String,
    position: json["position"] as int,
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "position": position,
  };
}

class ContentDeck {
  const ContentDeck({
    required this.id,
    required this.groupId,
    required this.name,
    required this.position,
    required this.cards,
  });

  final String id;
  final String groupId;
  final String name;
  final int position;
  final List<ContentCard> cards;

  factory ContentDeck.fromJson(Map<String, dynamic> json) => ContentDeck(
    id: json["id"] as String,
    groupId: json["groupId"] as String,
    name: json["name"] as String,
    position: json["position"] as int,
    cards: (json["cards"] as List)
        .map((c) => ContentCard.fromJson(c as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "groupId": groupId,
    "name": name,
    "position": position,
    "cards": [for (final c in cards) c.toJson()],
  };

  ContentDeck copyWith({List<ContentCard>? cards}) => ContentDeck(
    id: id,
    groupId: groupId,
    name: name,
    position: position,
    cards: cards ?? this.cards,
  );
}

class ContentCard {
  const ContentCard({
    required this.id,
    required this.position,
    required this.front,
    required this.back,
    this.hint,
    this.note,
    this.altAnswers = const [],
    this.typeAnswer = false,
    this.marked = false,
    this.hanja = false,
    this.passage = false,
    this.audio = CardAudio.none,
  });

  final String id;
  final int position;
  final String front;
  final String back;
  final String? hint;

  /// Xem [StudyWord.note].
  final String? note;
  final List<String> altAnswers;

  /// Xem [StudyWord.typeAnswer].
  final bool typeAnswer;
  final bool marked;
  final bool hanja;

  /// 📖 Đoạn văn ngắn — cờ người học tự gắn, giống ⭐/漢.
  final bool passage;

  /// Xem [StudyWord.audio].
  final CardAudio audio;

  /// Còn đọc được định dạng cũ `kr`/`vi` (chưa có kiểu thẻ): cache trên máy
  /// từ trước bản có thẻ tự chấm — phải mở được app offline ngay sau khi cập
  /// nhật. Thẻ cũ đều là thẻ gõ đáp án; lần đồng bộ sau sẽ thay bằng bản mới.
  /// `parentId` của thẻ ngữ cảnh (đã bỏ) trong cache cũ bị bỏ qua — thẻ con
  /// thành thẻ thường, giống server.
  factory ContentCard.fromJson(Map<String, dynamic> json) => ContentCard(
    id: json["id"] as String,
    position: json["position"] as int,
    front: (json["front"] ?? json["vi"]) as String,
    back: (json["back"] ?? json["kr"]) as String,
    hint: json["hint"] as String?,
    note: json["note"] as String?,
    altAnswers: (json["altAnswers"] as List?)?.cast<String>() ?? const [],
    typeAnswer: json["typeAnswer"] as bool? ?? json.containsKey("kr"),
    marked: json["marked"] as bool? ?? false,
    hanja: json["hanja"] as bool? ?? false,
    passage: json["passage"] as bool? ?? false,
    audio: CardAudio.fromJson(json),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "position": position,
    "front": front,
    "back": back,
    "hint": hint,
    "note": note,
    "altAnswers": altAnswers,
    "typeAnswer": typeAnswer,
    "marked": marked,
    "hanja": hanja,
    "passage": passage,
    ...audio.toJson(),
  };

  ContentCard copyWith({
    String? front,
    String? back,
    String? Function()? hint,
    String? Function()? note,
    List<String>? altAnswers,
    bool? typeAnswer,
    bool? marked,
    bool? hanja,
    bool? passage,
    CardAudio? audio,
  }) => ContentCard(
    id: id,
    position: position,
    front: front ?? this.front,
    back: back ?? this.back,
    hint: hint != null ? hint() : this.hint,
    note: note != null ? note() : this.note,
    altAnswers: altAnswers ?? this.altAnswers,
    typeAnswer: typeAnswer ?? this.typeAnswer,
    marked: marked ?? this.marked,
    hanja: hanja ?? this.hanja,
    passage: passage ?? this.passage,
    audio: audio ?? this.audio,
  );
}

/// Dữ liệu đã dựng sẵn cho [StudyEngine].
class StudyCatalog {
  const StudyCatalog({
    required this.decks,
    required this.vocabGroups,
    required this.markedIds,
    required this.hanjaIds,
    required this.passageIds,
  });

  final List<Deck> decks;
  final List<VocabGroup> vocabGroups;
  final Set<String> markedIds;
  final Set<String> hanjaIds;
  final Set<String> passageIds;
}

/// Dựng dữ liệu cho engine: sắp nhóm/bộ/thẻ theo `position`.
StudyCatalog buildStudyCatalog(ContentSnapshot content) {
  final groups = [...content.groups]
    ..sort((a, b) => a.position.compareTo(b.position));
  final decks = [...content.decks]
    ..sort((a, b) => a.position.compareTo(b.position));

  final marked = <String>{};
  final hanja = <String>{};
  final passage = <String>{};
  final studyDecks = <Deck>[];

  for (final d in decks) {
    final cards = [...d.cards]
      ..sort((a, b) => a.position.compareTo(b.position));
    final words = <StudyWord>[];
    for (final c in cards) {
      if (c.marked) marked.add(c.id);
      if (c.hanja) hanja.add(c.id);
      if (c.passage) passage.add(c.id);
      words.add(
        StudyWord(
          id: c.id,
          front: c.front,
          back: c.back,
          hint: c.hint,
          note: c.note,
          altAnswers: c.altAnswers.isEmpty ? null : c.altAnswers,
          typeAnswer: c.typeAnswer,
          audio: c.audio,
        ),
      );
    }
    studyDecks.add(
      Deck(id: d.id, name: d.name, group: d.groupId, words: words),
    );
  }

  return StudyCatalog(
    decks: studyDecks,
    vocabGroups: [for (final g in groups) VocabGroup(id: g.id, name: g.name)],
    markedIds: marked,
    hanjaIds: hanja,
    passageIds: passage,
  );
}
