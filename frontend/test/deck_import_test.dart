import "dart:convert";

import "package:flashcard_app/features/study_reading/domain/deck_import.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("đọc object {name, words} và bỏ khoảng trắng thừa", () {
    final r = parseDeckImport('''
{"name": " Sức khoẻ ", "words": [
  {"back": " 치아 ", "front": "răng", "hint": "  "},
  {"back": "건강", "front": "sức khoẻ", "hint": "kiện khang"}
]}''');
    expect(r.ok, isTrue);
    expect(r.name, "Sức khoẻ");
    expect(r.words, [
      {"front": "răng", "back": "치아", "typeAnswer": true},
      {
        "front": "sức khoẻ",
        "back": "건강",
        "typeAnswer": true,
        "hint": "kiện khang",
      },
    ]);
  });

  test("note (Markdown) giữ nguyên thụt lề/xuống dòng; rỗng thì bỏ", () {
    const md = "    code\n\n- **ý 1**\n  - ý lồng\n";
    final r = parseDeckImport(
      jsonEncode([
        {
          "back": "가다",
          "front": "đi",
          "note": md,
          "followUp": {"front": "đi học", "note": " \n "},
        },
      ]),
    );
    expect(r.ok, isTrue);
    expect(r.cards[0]["note"], md);
    expect(r.cards[1].containsKey("note"), isFalse);
  });

  test("chấp nhận mảng trần và khối ```json của AI", () {
    final r = parseDeckImport('''
Đây là kết quả:
```json
[{"back": "학교", "front": "trường học"}]
```
''');
    expect(r.ok, isTrue);
    expect(r.name, isNull);
    expect(r.words.single["back"], "학교");
  });

  test("thẻ ngữ cảnh: followUp đơn được đổi thành followUps, đếm đủ thẻ", () {
    final r = parseDeckImport(
      '''
[{"back": "가다", "front": "đi", "followUp": {"front": "đi học"}},
 {"back": "오다", "front": "đến", "followUps": [{"back": "집에 오다", "front": "về nhà"}, {"front": "đến đây"}]}]''',
    );
    expect(r.ok, isTrue);
    expect(r.words[0]["followUps"], [
      {"front": "đi học", "typeAnswer": true},
    ]);
    expect(r.cardCount, 5);
  });

  test("từ thiếu front/back -> báo lỗi đúng vị trí, không cho gửi", () {
    final r = parseDeckImport(
      '[{"back": "학교"}, {"back": "학생", "front": "học sinh"}]',
    );
    expect(r.ok, isFalse);
    expect(r.errors, ["Từ thứ 1: thiếu \"front\" hoặc \"back\"."]);
    expect(r.words, hasLength(1));
  });

  test("định dạng cũ kr/vi không còn được nhận", () {
    expect(parseDeckImport('[{"kr": "학교", "vi": "trường học"}]').ok, isFalse);
  });

  test("JSON hỏng và dữ liệu sai kiểu", () {
    expect(
      parseDeckImport("{không phải json").errors.single,
      startsWith("JSON"),
    );
    expect(parseDeckImport('{"words": 3}').ok, isFalse);
    expect(parseDeckImport("").ok, isFalse);
    expect(parseDeckImport("").errors, isEmpty); // ô trống không phải lỗi
  });

  test("báo từ đã có ở bộ khác (chỉ cảnh báo)", () {
    final r = parseDeckImport(
      '[{"back": "학교", "front": "trường"}, {"back": "새", "front": "chim"}]',
    );
    expect(r.duplicatesOf({"학교", "학생"}), ["학교"]);
    expect(r.ok, isTrue);
  });

  test("giới hạn 500 từ mỗi lần, khớp server", () {
    final many = List.generate(501, (i) => '{"back": "k$i", "front": "v"}');
    expect(parseDeckImport("[${many.join(",")}]").ok, isFalse);
  });

  group("Nhập đáp án", () {
    test(
      "không ghi typeAnswer: mặt sau ≤ 3 từ thì tick sẵn, dài hơn thì không",
      () {
        final r = parseDeckImport('''
[{"back": "간 이식 수술", "front": "ghép gan", "followUps": [
   {"back": "간 이식 수술을 하다", "front": "làm phẫu thuật ghép gan"},
   {"front": "mượn đáp án thẻ gốc"}]},
 {"back": "1일 2회, 1회 1정 복용", "front": "liều dùng"}]''');
        expect(r.cards.map((c) => c["typeAnswer"]), [true, false, true, false]);
        expect(r.typeAnswerCount, 2);
      },
    );

    test("ghi rõ typeAnswer thì giữ nguyên, kể cả thẻ ngữ cảnh", () {
      final r = parseDeckImport(
        '''
[{"back": "가다", "front": "đi", "typeAnswer": false,
  "followUp": {"back": "학교에 가서 공부를 하다", "front": "đi học", "typeAnswer": true}}]''',
      );
      expect(r.cards.map((c) => c["typeAnswer"]), [false, true]);
    });

    test("đổi ô tick qua cards là đổi đúng thứ gửi lên server", () {
      final r = parseDeckImport(
        '[{"back": "가다", "front": "đi", "followUp": {"front": "đi học"}}]',
      );
      r.cards[1]["typeAnswer"] = false;
      final ups = r.words[0]["followUps"] as List;
      expect((ups.single as Map)["typeAnswer"], isFalse);
    });

    test("defaultTypeAnswer đếm từ theo khoảng trắng", () {
      expect(defaultTypeAnswer("가다"), isTrue);
      expect(defaultTypeAnswer("  학교에   가다  "), isTrue);
      expect(defaultTypeAnswer("1일 2회 복용"), isTrue);
      expect(defaultTypeAnswer("1일 2회, 1회 1정 복용"), isFalse);
    });
  });
}
