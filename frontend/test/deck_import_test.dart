import "package:flashcard_app/features/study_reading/domain/deck_import.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("đọc object {name, words} và bỏ khoảng trắng thừa", () {
    final r = parseDeckImport('''
{"name": " Sức khoẻ ", "words": [
  {"kr": " 치아 ", "vi": "răng", "hint": "  "},
  {"kr": "건강", "vi": "sức khoẻ", "hint": "kiện khang"}
]}''');
    expect(r.ok, isTrue);
    expect(r.name, "Sức khoẻ");
    expect(r.words, [
      {"kr": "치아", "vi": "răng"},
      {"kr": "건강", "vi": "sức khoẻ", "hint": "kiện khang"},
    ]);
  });

  test("chấp nhận mảng trần và khối ```json của AI", () {
    final r = parseDeckImport('''
Đây là kết quả:
```json
[{"kr": "학교", "vi": "trường học"}]
```
''');
    expect(r.ok, isTrue);
    expect(r.name, isNull);
    expect(r.words.single["kr"], "학교");
  });

  test("thẻ ngữ cảnh: followUp đơn được đổi thành followUps, đếm đủ thẻ", () {
    final r = parseDeckImport(
      '''
[{"kr": "가다", "vi": "đi", "followUp": {"vi": "đi học"}},
 {"kr": "오다", "vi": "đến", "followUps": [{"kr": "집에 오다", "vi": "về nhà"}, {"vi": "đến đây"}]}]''',
    );
    expect(r.ok, isTrue);
    expect(r.words[0]["followUps"], [
      {"vi": "đi học"},
    ]);
    expect(r.cardCount, 5);
  });

  test("từ thiếu kr/vi -> báo lỗi đúng vị trí, không cho gửi", () {
    final r = parseDeckImport('[{"kr": "학교"}, {"kr": "학생", "vi": "học sinh"}]');
    expect(r.ok, isFalse);
    expect(r.errors, ["Từ thứ 1: thiếu \"kr\" hoặc \"vi\"."]);
    expect(r.words, hasLength(1));
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
      '[{"kr": "학교", "vi": "trường"}, {"kr": "새", "vi": "chim"}]',
    );
    expect(r.duplicatesOf({"학교", "학생"}), ["학교"]);
    expect(r.ok, isTrue);
  });

  test("giới hạn 500 từ mỗi lần, khớp server", () {
    final many = List.generate(501, (i) => '{"kr": "k$i", "vi": "v"}');
    expect(parseDeckImport("[${many.join(",")}]").ok, isFalse);
  });
}
