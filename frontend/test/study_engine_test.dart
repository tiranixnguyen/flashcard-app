import "package:flashcard_app/features/study_reading/domain/study_engine.dart";
import "package:flashcard_app/features/study_reading/models/content.dart";
import "package:flutter_test/flutter_test.dart";

import "support/fixtures.dart";

StudyEngine buildEngine({List<Map<String, dynamic>>? words}) =>
    engineFor(contentOf([contentDeck("d1", words ?? threeWords)]));

/// Trả lời đúng thẻ đang hiển thị, dù nó là thẻ nào.
void answerCurrentCorrectly(StudyEngine e) {
  expect(e.checkAnswer(e.currentWord!.kr), isTrue);
}

/// Học tới khi thẻ đang hỏi thoả [test] (trả lời bằng "Xem đáp án").
void skipUntil(StudyEngine e, bool Function(StudyEngine) test) {
  while (!test(e)) {
    e.revealAnswer();
    e.nextCard();
  }
}

const withFollowUp = [
  {
    "kr": "가다",
    "vi": "đi",
    "followUp": {"kr": "학교에 가다", "vi": "đi đến trường"},
  },
  {"kr": "학생", "vi": "học sinh"},
  {"kr": "학교", "vi": "trường học"},
];

void main() {
  group("dựng dữ liệu (buildStudyCatalog)", () {
    test("nối thẻ ngữ cảnh vào danh sách phẳng và liên kết hai chiều", () {
      final c = buildStudyCatalog(
        contentOf([
          contentDeck("d1", [
            {
              "kr": "가다",
              "vi": "đi",
              "followUps": [
                {"kr": "학교에 가다", "vi": "đi đến trường"},
                {"vi": "đi thôi"},
              ],
            },
          ]),
        ]),
      );
      final words = c.decks.single.words;

      expect(words, hasLength(3));
      expect(words[0].followUpIndex, 1);
      expect(words[1].followUpIndex, 2);
      expect(words[2].followUpIndex, isNull);
      expect(words[1].impliesIndex, 0);
      expect(words[2].impliesIndex, 0);
      expect(words[2].kr, "가다"); // thiếu kr thì mượn của thẻ gốc
    });

    test("sắp theo position, không theo thứ tự trong JSON", () {
      final deck = contentDeck("d1", threeWords);
      final shuffled = deck.copyWith(cards: deck.cards.reversed.toList());
      final c = buildStudyCatalog(contentOf([shuffled]));
      expect(c.decks.single.words.map((w) => w.kr), ["학생", "선생님", "학교"]);
    });

    test("gom cờ ⭐/漢 theo id thẻ", () {
      final c = buildStudyCatalog(
        contentOf([
          contentDeck("d1", threeWords, marked: {1}, hanja: {0, 2}),
        ]),
      );
      expect(c.markedIds, {"d1-1"});
      expect(c.hanjaIds, {"d1-0", "d1-2"});
    });
  });

  group("chấm bài", () {
    test("chấp nhận đáp án phụ và bỏ qua khoảng trắng thừa", () {
      final e = buildEngine(
        words: [
          {
            "kr": "감사합니다",
            "vi": "cảm ơn",
            "altAnswers": ["고맙습니다"],
          },
        ],
      );

      expect(e.checkAnswer("  고맙습니다  "), isTrue);
      expect(e.correctCount, 1);
      expect(e.attemptedCount, 1);
    });

    test("đáp án rỗng không bị tính là một lần trả lời", () {
      final e = buildEngine();
      expect(e.checkAnswer("   "), isFalse);
      expect(e.attemptedCount, 0);
      expect(e.answered, isFalse);
    });

    test("thẻ đã trả lời thì không chấm lại", () {
      final e = buildEngine();
      e.checkAnswer("sai bét");
      final attempts = e.attemptedCount;
      e.checkAnswer(e.currentWord!.kr);
      expect(e.attemptedCount, attempts);
    });
  });

  group("lịch Leitner", () {
    test(
      "đúng ${StudyEngine.masteryStreak} lần liên tiếp thì thẻ thành 'thuộc'",
      () {
        final e = buildEngine(
          words: [
            {"kr": "학생", "vi": "học sinh"},
          ],
        );

        for (var i = 0; i < StudyEngine.masteryStreak; i++) {
          answerCurrentCorrectly(e);
          e.nextCard();
        }

        expect(e.masteredCount, 1);
        expect(e.isCompleted, isTrue);
      },
    );

    test("trả lời sai đặt lại streak và box về 0", () {
      final e = buildEngine(
        words: [
          {"kr": "학생", "vi": "học sinh"},
          {"kr": "학교", "vi": "trường học"},
        ],
      );

      answerCurrentCorrectly(e);
      expect(e.currentProgress!.streak, 1);
      expect(e.currentProgress!.box, 1);

      e.nextCard();
      final target = e.currentWord!.kr;
      e.checkAnswer("đáp án sai");
      expect(e.outcome, AnswerOutcome.wrong);

      // Tìm lại đúng thẻ vừa sai để kiểm tra trạng thái của nó.
      while (e.currentWord!.kr != target) {
        e.nextCard();
      }
      expect(e.currentProgress!.streak, 0);
      expect(e.currentProgress!.box, 0);
    });

    test("thẻ trả lời sai được chèn lại vào hàng đợi", () {
      final e = buildEngine();
      final before = e.remainingInRound;
      e.checkAnswer("đáp án sai");
      expect(e.remainingInRound, before + 1);
    });

    test("mỗi lượt hỏi mới tăng cardSerial, kể cả hỏi lại cùng thẻ", () {
      final e = buildEngine(
        words: [
          {"kr": "학생", "vi": "học sinh"},
        ],
      );
      final first = e.cardSerial;
      e.checkAnswer("sai");
      e.nextCard();
      expect(e.currentWord!.kr, "학생");
      expect(e.cardSerial, greaterThan(first));
    });
  });

  group("tự xác nhận đúng", () {
    test("hoàn tác nhánh sai và áp lại lịch theo hướng đúng", () {
      final e = buildEngine();

      answerCurrentCorrectly(e); // box 0 -> 1, streak 0 -> 1
      e.nextCard();
      while (e.currentProgress!.streak != 1) {
        e.nextCard();
      }

      e.checkAnswer("gõ nhầm chính tả");
      expect(e.canOverride, isTrue);
      expect(e.overridden, isFalse);

      e.overrideAsCorrect();
      expect(e.outcome, AnswerOutcome.correct);
      expect(e.canOverride, isFalse);
      expect(e.overridden, isTrue);

      e.nextCard();
      expect(e.overridden, isFalse); // cờ chỉ thuộc về lượt vừa sửa
      // Streak nối tiếp từ 1 chứ không phải khởi động lại từ 0.
      expect(e.currentProgress!.streak, 2);
      expect(e.currentProgress!.box, 2);
    });

    test("không cho tự xác nhận đúng sau khi bấm 'Xem đáp án'", () {
      final e = buildEngine();
      e.revealAnswer();
      expect(e.outcome, AnswerOutcome.wrong);
      expect(e.canOverride, isFalse);

      e.overrideAsCorrect();
      expect(e.correctCount, 0); // không ghi nhận gì
    });
  });

  group("thẻ ngữ cảnh", () {
    test("trả lời xong thẻ gốc thì thẻ ngữ cảnh được hỏi ngay sau đó", () {
      final e = buildEngine(words: withFollowUp);

      skipUntil(e, (e) => e.currentWord!.followUpIndex != null);
      answerCurrentCorrectly(e);
      e.nextCard();

      expect(e.currentWord!.isFollowUp, isTrue);
      expect(e.currentWord!.vi, "đi đến trường");
    });

    test("đúng thẻ ngữ cảnh thì thẻ gốc được tính là đã thuộc", () {
      final e = buildEngine(words: [withFollowUp.first]);

      answerCurrentCorrectly(e); // thẻ gốc
      e.nextCard();
      expect(e.currentWord!.isFollowUp, isTrue);

      answerCurrentCorrectly(e); // thẻ ngữ cảnh -> kéo theo thẻ gốc
      expect(e.masteredCount, greaterThanOrEqualTo(1));
    });
  });

  group("đánh dấu và deck ảo", () {
    test("toggle trả về giá trị mới và dựng được deck ⭐ tương ứng", () {
      final e = buildEngine();
      expect(e.markedCount, 0);

      expect(e.toggleMark(), isTrue);
      expect(e.currentIsMarked, isTrue);
      expect(e.markedCount, 1);

      expect(e.toggleMark(), isFalse);
      expect(e.currentIsMarked, isFalse);
      expect(e.markedCount, 0);
    });

    test("cờ Hán Hàn tách biệt với cờ khó nhớ", () {
      final e = buildEngine();
      e.toggleHanja();
      expect(e.currentIsHanja, isTrue);
      expect(e.currentIsMarked, isFalse);
      expect(e.hanjaCount, 1);
      expect(e.markedCount, 0);
    });

    test("cờ có sẵn từ nội dung được nạp theo id thẻ", () {
      final e = engineFor(
        contentOf([
          contentDeck("d1", threeWords, marked: {2}),
        ]),
      );
      expect(e.markedCount, 1);
      e.switchDeck(markedDeckId);
      expect(e.currentWord!.kr, "학교");
      // Thẻ trong bộ ảo giữ id thẻ gốc -> bỏ cờ ở đây là bỏ cờ thẻ thật.
      expect(e.currentWord!.id, "d1-2");
      expect(e.currentIsMarked, isTrue);
    });

    test("chuyển sang deck ⭐ thì học đúng các từ đã đánh dấu", () {
      final e = buildEngine();
      final marked = e.currentWord!.kr;
      e.toggleMark();

      e.switchDeck(markedDeckId);
      expect(e.currentDeckId, markedDeckId);
      expect(e.totalCount, 1);
      expect(e.currentWord!.kr, marked);
    });

    test("deck ⭐ chỉ gồm từ của nhóm đang mở", () {
      final e = engineFor(
        contentOf(
          [
            contentDeck("d1", threeWords, marked: {0}),
            contentDeck("d2", threeWords, groupId: "g2", marked: {0, 1}),
          ],
          groups: const [
            ContentGroup(id: "g1", name: "Sep1", position: 0),
            ContentGroup(id: "g2", name: "Sep2", position: 1),
          ],
        ),
      );
      expect(e.markedCount, 1);
      e.switchVocabGroup("g2");
      expect(e.markedCount, 2);
    });

    test("bỏ ⭐ ngay trong deck ⭐: thẻ ở lại tới khi sang thẻ tiếp, "
        "rồi không bao giờ quay lại", () {
      final e = engineFor(
        contentOf([
          contentDeck("d1", threeWords, marked: {0, 1}),
        ]),
      );
      e.switchDeck(markedDeckId);
      final dropped = e.currentWord!.id;

      expect(e.toggleMark(), isFalse);
      expect(e.currentWord!.id, dropped); // vẫn xem được đáp án
      expect(e.totalCount, 2);

      e.revealAnswer(); // sai -> bình thường sẽ bị chèn lại vào hàng đợi
      e.nextCard();
      expect(e.totalCount, 1);
      expect(e.currentWord!.id, isNot(dropped));

      // Học hết thẻ còn lại -> hoàn thành, thẻ đã bỏ cờ không hiện lại.
      for (var i = 0; i < StudyEngine.masteryStreak; i++) {
        expect(e.currentWord!.id, isNot(dropped));
        answerCurrentCorrectly(e);
        e.nextCard();
      }
      expect(e.isCompleted, isTrue);
      expect(e.currentWord, isNull);
    });

    test("bỏ ⭐ rồi bật lại trước khi sang thẻ tiếp thì thẻ vẫn ở lại", () {
      final e = engineFor(
        contentOf([
          contentDeck("d1", threeWords, marked: {0, 1}),
        ]),
      );
      e.switchDeck(markedDeckId);
      e.toggleMark();
      e.toggleMark();
      e.revealAnswer();
      e.nextCard();
      expect(e.totalCount, 2);
    });

    test("bỏ cờ thẻ cuối cùng trong deck 漢 thì deck rỗng, không crash", () {
      final e = engineFor(
        contentOf([
          contentDeck("d1", threeWords, hanja: {2}),
        ]),
      );
      e.switchDeck(hanjaDeckId);
      e.toggleHanja();
      e.markKnown();
      e.nextCard();
      expect(e.totalCount, 0);
      expect(e.currentWord, isNull);
    });
  });

  group("mỗi lần vào bộ là một lượt mới", () {
    test("quay lại bộ vừa học dở thì bắt đầu lại từ đầu", () {
      final e = buildEngine();
      answerCurrentCorrectly(e);
      e.nextCard();
      expect(e.attemptedCount, 1);

      e.toggleMark();
      e.switchDeck(markedDeckId);
      e.switchDeck("d1");

      expect(e.attemptedCount, 0);
      expect(e.masteredCount, 0);
      expect(e.remainingInRound, e.totalCount);
    });

    test("học lại từ đầu xoá tiến trình lượt này", () {
      final e = buildEngine(
        words: [
          {"kr": "학생", "vi": "học sinh"},
        ],
      );
      for (var i = 0; i < StudyEngine.masteryStreak; i++) {
        answerCurrentCorrectly(e);
        e.nextCard();
      }
      expect(e.isCompleted, isTrue);

      e.restartCurrentDeck();
      expect(e.isCompleted, isFalse);
      expect(e.attemptedCount, 0);
    });
  });

  group("nội dung thay đổi giữa lượt (replaceContent)", () {
    test("sửa thẻ: giữ nguyên lượt học, thẻ đang hỏi hiện nội dung mới", () {
      final content = contentOf([contentDeck("d1", threeWords)]);
      final e = engineFor(content);
      answerCurrentCorrectly(e);
      final id = e.currentWord!.id;
      final serial = e.cardSerial;

      final changed = replaceWith(
        e,
        content.updateCard(id, (c) => c.copyWith(vi: "nghĩa mới")),
      );

      expect(changed, isFalse);
      expect(e.currentWord!.id, id);
      expect(e.currentWord!.vi, "nghĩa mới");
      expect(e.cardSerial, serial); // ô nhập không bị dọn
      expect(e.answered, isTrue);
      expect(e.currentProgress!.streak, 1);
      expect(e.attemptedCount, 1);
    });

    test("xoá thẻ đang hỏi: chuyển sang thẻ khác, thẻ đó không quay lại", () {
      final content = contentOf([contentDeck("d1", threeWords)]);
      final e = engineFor(content);
      final gone = e.currentWord!.id;

      final changed = replaceWith(e, content.removeCard(gone));

      expect(changed, isTrue);
      expect(e.totalCount, 2);
      final seen = <String>{};
      for (var i = 0; i < 6; i++) {
        seen.add(e.currentWord!.id);
        e.revealAnswer();
        e.nextCard();
      }
      expect(seen, isNot(contains(gone)));
    });

    test("xoá thẻ gốc thì thẻ ngữ cảnh của nó cũng rơi ra", () {
      final content = contentOf([contentDeck("d1", withFollowUp)]);
      final e = engineFor(content);
      expect(e.totalCount, 4);
      replaceWith(e, content.removeCard("d1-0"));
      expect(e.totalCount, 2);
    });

    test("thêm từ vào bộ đang học: từ mới được hỏi trong lượt này", () {
      final deck = contentDeck("d1", threeWords.take(2).toList());
      final e = engineFor(contentOf([deck]));
      final more = contentDeck("d1", threeWords);

      replaceWith(e, contentOf([more]));

      expect(e.totalCount, 3);
      final seen = <String>{};
      for (var i = 0; i < 10; i++) {
        seen.add(e.currentWord!.kr);
        e.revealAnswer();
        e.nextCard();
      }
      expect(seen, contains("학교"));
    });

    test("thẻ đã thuộc vẫn là đã thuộc sau khi tải lại", () {
      final content = contentOf([contentDeck("d1", threeWords)]);
      final e = engineFor(content);
      e.markKnown();
      expect(e.masteredCount, 1);
      replaceWith(e, content);
      expect(e.masteredCount, 1);
    });

    test("bộ đang học bị xoá thì mở bộ đầu tiên của nhóm", () {
      final e = engineFor(
        contentOf([
          contentDeck("d1", threeWords),
          contentDeck("d2", threeWords, position: 1),
        ]),
      );
      e.switchDeck("d2");

      final changed = replaceWith(
        e,
        contentOf([contentDeck("d1", threeWords)]),
      );

      expect(changed, isTrue);
      expect(e.currentDeckId, "d1");
    });

    test("bỏ ⭐ trên máy khác khi đang học deck ⭐: thẻ rơi khỏi lượt", () {
      final content = contentOf([
        contentDeck("d1", threeWords, marked: {0, 1}),
      ]);
      final e = engineFor(content);
      e.switchDeck(markedDeckId);
      expect(e.totalCount, 2);

      replaceWith(
        e,
        content.updateCard("d1-0", (c) => c.copyWith(marked: false)),
      );
      expect(e.currentDeckId, markedDeckId);
      expect(e.totalCount, 1);
      expect(e.currentWord!.id, "d1-1");
    });
  });
}
