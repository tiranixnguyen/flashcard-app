/// Mục danh sách: dấu (`*`/`-`/`+`/`1.`/`1)`) + khoảng trắng, rồi nội dung.
final _listItem = RegExp(r"^([*+-]|\d+[.)])([ \t]+)(.*)$");

/// Mục danh sách có thụt lề — văn bản đã có cấp lồng thật.
final _indentedListItem = RegExp(r"^[ \t]+([*+-]|\d+[.)])[ \t]");

/// Nội dung chỉ là một cụm đậm kết thúc bằng dấu `:` — vd `**Use case 1:**`
/// hoặc `**Use case 1**:`.
final _boldHeading = RegExp(r"^\*\*[^*].*?(:\*\*|\*\*:)\s*$");

/// Dựng lại cấp lồng của danh sách bị mất thụt lề khi copy từ giao diện chat
/// AI (copy phần chữ đã hiển thị thay vì Markdown gốc — mọi `* ` đều về cột 0):
///
/// ```
/// * **Use case 1 (…):**      ->  * **Use case 1 (…):**
/// * *Bối cảnh:* …                 * *Bối cảnh:* …
/// ```
///
/// Mục chỉ gồm chữ đậm kết thúc bằng `:` được coi là "tiêu đề"; các dòng ngay
/// sau nó (tới dòng trống hoặc tiêu đề kế tiếp) thụt vào thành mục con. Chỉ
/// dùng lúc hiển thị — dữ liệu lưu giữ nguyên bản dán. Văn bản đã có mục thụt
/// lề (Markdown gốc) thì trả nguyên, không đoán.
String nestFlattenedLists(String md) {
  final lines = md.split("\n");
  if (lines.any(_indentedListItem.hasMatch)) return md;

  final out = <String>[];
  var inFence = false;
  String? childIndent; // khác null = đang ở dưới một mục tiêu đề
  for (final line in lines) {
    if (line.trimLeft().startsWith("```")) {
      inFence = !inFence;
      childIndent = null;
      out.add(line);
      continue;
    }
    if (inFence) {
      out.add(line);
      continue;
    }
    if (line.trim().isEmpty) {
      childIndent = null;
      out.add(line);
      continue;
    }
    final item = _listItem.firstMatch(line);
    if (item != null && _boldHeading.hasMatch(item.group(3)!)) {
      // Mục con phải thụt tới đúng chỗ nội dung của mục cha bắt đầu.
      childIndent = " " * (item.group(1)!.length + item.group(2)!.length);
      out.add(line);
      continue;
    }
    out.add(childIndent == null ? line : "$childIndent$line");
  }
  return out.join("\n");
}
