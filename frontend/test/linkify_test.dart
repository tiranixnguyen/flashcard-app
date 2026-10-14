import "package:flashcard_app/features/study_reading/domain/linkify.dart";
import "package:flutter_test/flutter_test.dart";

String _join(List<TextSegment> s) => s.map((e) => e.text).join();

void main() {
  test("không có link -> một đoạn chữ", () {
    expect(linkify("Bài nghe số 3"), [const TextSegment("Bài nghe số 3")]);
    expect(linkify(""), isEmpty);
  });

  test("tách link giữa câu, ghép lại đúng chữ gốc", () {
    const text = "Nghe ở https://youtu.be/abc?t=10 rồi làm http://a.vn/x";
    final s = linkify(text);
    expect(_join(s), text);
    expect(
      [for (final e in s) e.link?.toString()],
      [null, "https://youtu.be/abc?t=10", null, "http://a.vn/x"],
    );
  });

  test("dấu câu cuối không tính vào link; ngoặc cân bằng thì giữ", () {
    final a = linkify("Xem https://a.com/b.");
    expect(a[1].link, Uri.parse("https://a.com/b"));
    expect(a.last, const TextSegment("."));

    final b = linkify("(https://a.com/x)");
    expect(b[1].link, Uri.parse("https://a.com/x"));
    expect(b.last.text, ")");

    final c = linkify("https://en.wikipedia.org/wiki/Hangul_(script)");
    expect(c.single.text, "https://en.wikipedia.org/wiki/Hangul_(script)");
  });

  test("xuống dòng và chữ Hàn quanh link", () {
    const text = "듣기 연습:\nhttps://example.com/listen\n끝";
    final s = linkify(text);
    expect(_join(s), text);
    expect(
      s.where((e) => e.link != null).single.text,
      "https://example.com/listen",
    );
  });

  test("không có host hoặc không phải http(s) -> chữ thường", () {
    expect(linkify("https:// trống").every((e) => e.link == null), isTrue);
    expect(linkify("ftp://a.com").every((e) => e.link == null), isTrue);
  });
}
