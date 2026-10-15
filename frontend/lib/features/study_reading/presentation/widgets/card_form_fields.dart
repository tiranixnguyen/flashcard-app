import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/platform/keyboard_language.dart";
import "../../../../core/theme/app_palette.dart";
import "../../models/card_audio.dart";

/// Nội dung các ô của một thẻ. Dùng chung cho dialog sửa thẻ và chế độ "Nhập
/// tay" khi thêm từ — hai nơi luôn cùng giao diện.
class CardForm {
  CardForm({
    String front = "",
    String back = "",
    String hint = "",
    String note = "",
    List<String> altAnswers = const [],
    this.typeAnswer = true,
  }) : front = TextEditingController(text: front),
       back = TextEditingController(text: back),
       hint = TextEditingController(text: hint),
       note = TextEditingController(text: note),
       alts = [for (final a in altAnswers) TextEditingController(text: a)];

  final TextEditingController front;
  final TextEditingController back;
  final TextEditingController hint;
  final TextEditingController note;
  final List<TextEditingController> alts;
  bool typeAnswer;

  bool get hasBothSides =>
      front.text.trim().isNotEmpty && back.text.trim().isNotEmpty;

  void dispose() {
    front.dispose();
    back.dispose();
    hint.dispose();
    note.dispose();
    for (final c in alts) {
      c.dispose();
    }
  }
}

/// Các ô nhập của [form]: mặt trước, mặt sau, "Nhập đáp án", đáp án đúng
/// khác, gợi ý, giải thích. [onChanged] gọi sau mỗi thay đổi (cha `setState`).
/// [audioControl] (dialog sửa thẻ) đặt nút file nghe bên phải nhãn trường.
/// [onSubmitted]: Enter ở ô một dòng.
class CardFormFields extends StatelessWidget {
  const CardFormFields({
    super.key,
    required this.form,
    required this.palette,
    required this.onChanged,
    this.audioControl,
    this.onSubmitted,
    this.enabled = true,
  });

  final CardForm form;
  final AppPalette palette;
  final VoidCallback onChanged;
  final Widget Function(CardField field)? audioControl;
  final VoidCallback? onSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label("Mặt trước — nghĩa tiếng Việt", audio: CardField.front),
        _field(form.front),
        const SizedBox(height: 14),
        _label("Mặt sau — tiếng Hàn (đáp án chính)", audio: CardField.back),
        _field(form.back, korean: true),
        const SizedBox(height: 6),
        CheckboxListTile(
          value: form.typeAnswer,
          onChanged: enabled
              ? (v) {
                  form.typeAnswer = v ?? false;
                  onChanged();
                }
              : null,
          title: Text(
            "Nhập đáp án",
            style: GoogleFonts.notoSans(fontSize: 14, color: p.ink),
          ),
          subtitle: Text(
            form.typeAnswer
                ? "Gõ mặt sau rồi chấm."
                : "Thẻ tự chấm: lật thẻ rồi tự bấm Nhớ / Chưa nhớ.",
            style: GoogleFonts.notoSans(fontSize: 12, color: p.inkSoft),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        const SizedBox(height: 8),
        _label("Đáp án đúng khác (không bắt buộc)"),
        for (var i = 0; i < form.alts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: _field(form.alts[i], korean: true)),
                IconButton(
                  tooltip: "Xoá đáp án này",
                  onPressed: enabled
                      ? () {
                          form.alts.removeAt(i).dispose();
                          onChanged();
                        }
                      : null,
                  icon: Icon(Icons.close, size: 18, color: p.wrong),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: enabled
              ? () {
                  form.alts.add(TextEditingController());
                  onChanged();
                }
              : null,
          icon: Icon(Icons.add, size: 16, color: p.blue),
          label: Text("Thêm đáp án đúng khác", style: TextStyle(color: p.blue)),
        ),
        const SizedBox(height: 8),
        _label("Gợi ý (không bắt buộc)", audio: CardField.hint),
        // Cao sẵn 3 dòng, giãn tới 5 dòng rồi cuộn bên trong — gợi ý thật
        // trong dữ liệu có cái dài hơn chục dòng (chiết tự Hán tự).
        _field(form.hint, minLines: 3, maxLines: 5),
        const SizedBox(height: 14),
        _label("Giải thích đáp án (không bắt buộc)", audio: CardField.note),
        Text(
          "Dán thẳng từ AI — giữ nguyên định dạng Markdown (tiêu đề, "
          "**đậm**, danh sách, bảng…). Hiện sau khi lộ đáp án.",
          style: GoogleFonts.notoSans(fontSize: 12, color: p.inkSoft),
        ),
        const SizedBox(height: 6),
        // Giải thích có thể rất dài: cao sẵn 4 dòng, giãn tới 12 dòng rồi
        // cuộn bên trong.
        _field(form.note, minLines: 4, maxLines: 12),
      ],
    );
  }

  /// Nhãn trường; có [audio] và [audioControl] thì bên phải là nút file nghe.
  Widget _label(String text, {CardField? audio}) {
    final label = Text(
      text,
      style: GoogleFonts.notoSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: palette.inkSoft,
      ),
    );
    final control = audio == null ? null : audioControl?.call(audio);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: control == null
          ? label
          : Row(
              children: [
                Expanded(child: label),
                control,
              ],
            ),
    );
  }

  Widget _field(
    TextEditingController controller, {
    bool korean = false,
    int minLines = 1,
    int maxLines = 1,
  }) {
    final p = palette;
    final field = TextField(
      controller: controller,
      enabled: enabled,
      onChanged: (_) => onChanged(),
      // Chỉ ô một dòng: ô nhiều dòng thì Enter là xuống dòng.
      onSubmitted: maxLines == 1 && onSubmitted != null
          ? (_) => onSubmitted!()
          : null,
      // Ô tiếng Hàn: Android tự chuyển bàn phím qua hintLocales; iOS qua
      // KeyboardLanguageScope bên dưới. Ô tiếng Việt để trống -> bàn phím
      // quay về ngôn ngữ đang dùng trước đó.
      hintLocales: korean ? koreanKeyboard : null,
      // maxLines > 1 thì bàn phím tự thành multiline: Enter xuống dòng thay
      // vì submit — đúng ý cho gợi ý nhiều dòng (vd chiết tự Hán tự).
      minLines: minLines,
      maxLines: maxLines,
      style: korean
          ? GoogleFonts.notoSansKr(fontSize: 16, color: p.ink)
          : GoogleFonts.notoSans(fontSize: 15, color: p.ink),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: p.paperLine),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: p.paperLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: p.blue, width: 1.5),
        ),
      ),
    );
    return korean
        ? KeyboardLanguageScope(languageCode: "ko", child: field)
        : field;
  }
}
