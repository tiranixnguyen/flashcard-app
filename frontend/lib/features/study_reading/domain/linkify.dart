/// Một đoạn của chữ đã tách link: [link] khác `null` là đoạn bấm được.
class TextSegment {
  const TextSegment(this.text, [this.link]);

  final String text;
  final Uri? link;

  @override
  bool operator ==(Object other) =>
      other is TextSegment && other.text == text && other.link == link;

  @override
  int get hashCode => Object.hash(text, link);

  @override
  String toString() => link == null ? "Text($text)" : "Link($text)";
}

final _url = RegExp(r"https?://[^\s<>\x22]+", caseSensitive: false);

/// Dấu câu hay dính ngay sau link trong câu văn ("xem https://a.com.") — không
/// tính vào link.
const _trailing = ".,;:!?'\x22";

/// Tách [text] thành đoạn chữ thường và đoạn link `http(s)://`. Chữ ghép lại
/// từ các đoạn luôn đúng bằng [text].
List<TextSegment> linkify(String text) {
  final out = <TextSegment>[];
  var start = 0;
  for (final m in _url.allMatches(text)) {
    var end = m.end;
    while (end > m.start) {
      final c = text[end - 1];
      final unbalancedParen =
          c == ")" &&
          "(".allMatches(text.substring(m.start, end)).length <
              ")".allMatches(text.substring(m.start, end)).length;
      if (!_trailing.contains(c) && !unbalancedParen) break;
      end--;
    }
    final uri = Uri.tryParse(text.substring(m.start, end));
    if (uri == null || uri.host.isEmpty) continue;
    if (m.start > start) out.add(TextSegment(text.substring(start, m.start)));
    out.add(TextSegment(text.substring(m.start, end), uri));
    start = end;
  }
  if (start < text.length) out.add(TextSegment(text.substring(start)));
  return out;
}
