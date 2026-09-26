import "dart:convert";
import "dart:io";
import "dart:math";

import "package:flashcard_app/features/study_reading/domain/study_engine.dart";
import "package:flashcard_app/features/study_reading/models/content.dart";
import "package:flutter_test/flutter_test.dart";

/// Kiểm tra chính nội dung đóng gói trong app (`assets/content.json`, xuất từ
/// DB bằng `npm run export-content`) — đây là thứ người học thấy ở lần mở đầu
/// tiên khi chưa có mạng. Bắt lỗi asset hỏng/sai định dạng trước khi người
/// học gặp màn hình trắng.
void main() {
  late final content = ContentSnapshot.fromJson(
    jsonDecode(File("assets/content.json").readAsStringSync())
        as Map<String, dynamic>,
  );
  late final catalog = buildStudyCatalog(content);

  test("parse được và có dữ liệu", () {
    expect(content.groups, isNotEmpty);
    expect(content.decks, isNotEmpty);
    expect(content.decks.expand((d) => d.cards), isNotEmpty);
  });

  test("id thẻ không trùng trên toàn bộ nội dung", () {
    final ids = [for (final d in content.decks) ...d.cards.map((c) => c.id)];
    expect(ids.toSet(), hasLength(ids.length));
  });

  test("mọi thẻ có đủ mặt trước và mặt sau", () {
    for (final d in content.decks) {
      for (final c in d.cards) {
        expect(c.back.trim(), isNotEmpty, reason: c.id);
        expect(c.front.trim(), isNotEmpty, reason: c.id);
      }
    }
  });

  test("thẻ ngữ cảnh trỏ về thẻ gốc cùng bộ, đứng trước nó", () {
    for (final d in content.decks) {
      final byId = {for (final c in d.cards) c.id: c};
      for (final c in d.cards) {
        final parentId = c.parentId;
        if (parentId == null) continue;
        final parent = byId[parentId];
        expect(parent, isNotNull, reason: "${c.id} -> $parentId");
        expect(parent!.parentId, isNull, reason: "chỉ một tầng: ${c.id}");
        expect(parent.position, lessThan(c.position), reason: c.id);
      }
    }
  });

  test("mỗi bộ thuộc một nhóm đã khai báo", () {
    final groupIds = content.groups.map((g) => g.id).toSet();
    for (final d in content.decks) {
      expect(groupIds, contains(d.groupId), reason: d.id);
    }
  });

  test("dựng catalog không rơi thẻ hay cờ ⭐/漢 nào", () {
    final cards = content.decks.expand((d) => d.cards).toList();
    expect(
      catalog.decks.fold<int>(0, (n, d) => n + d.words.length),
      cards.length,
    );
    expect(catalog.markedIds, {
      for (final c in cards)
        if (c.marked) c.id,
    });
    expect(catalog.hanjaIds, {
      for (final c in cards)
        if (c.hanja) c.id,
    });
  });

  test("engine khởi động được và hỏi ra thẻ đầu tiên", () {
    final engine = StudyEngine(
      decks: catalog.decks,
      vocabGroups: catalog.vocabGroups,
      markedIds: catalog.markedIds,
      hanjaIds: catalog.hanjaIds,
      random: Random(7),
    )..bootstrap();

    expect(engine.currentWord, isNotNull);
    expect(engine.totalCount, greaterThan(0));
    expect(engine.isCompleted, isFalse);
  });

  test("deck ngẫu nhiên rút tối đa 20 thẻ gốc từ nhóm đang học", () {
    final engine = StudyEngine(
      decks: catalog.decks,
      vocabGroups: catalog.vocabGroups,
      random: Random(7),
    )..bootstrap();

    engine.switchDeck(randomDeckId);
    expect(engine.totalCount, lessThanOrEqualTo(20));
    expect(engine.currentWord!.isFollowUp, isFalse);
  });
}
