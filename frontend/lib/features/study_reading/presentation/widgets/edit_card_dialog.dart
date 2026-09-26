import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/platform/keyboard_language.dart";
import "../../../../core/theme/app_palette.dart";
import "../../models/study_word.dart";

/// Kết quả người dùng chọn trong hộp thoại sửa thẻ.
sealed class EditCardResult {
  const EditCardResult();
}

class EditCardSaved extends EditCardResult {
  const EditCardSaved({
    required this.vi,
    required this.kr,
    this.hint,
    this.altAnswers = const [],
  });

  final String vi;
  final String kr;
  final String? hint;
  final List<String> altAnswers;
}

class EditCardDeleted extends EditCardResult {
  const EditCardDeleted();
}

Future<EditCardResult?> showEditCardDialog({
  required BuildContext context,
  required AppPalette palette,
  required StudyWord word,
}) {
  return showDialog<EditCardResult>(
    context: context,
    builder: (_) => _EditCardDialog(palette: palette, word: word),
  );
}

class _EditCardDialog extends StatefulWidget {
  const _EditCardDialog({required this.palette, required this.word});

  final AppPalette palette;
  final StudyWord word;

  @override
  State<_EditCardDialog> createState() => _EditCardDialogState();
}

class _EditCardDialogState extends State<_EditCardDialog> {
  late final _viController = TextEditingController(text: widget.word.vi);
  late final _krController = TextEditingController(text: widget.word.kr);
  late final _hintController = TextEditingController(
    text: widget.word.hint ?? "",
  );
  late final List<TextEditingController> _altControllers = [
    for (final alt in widget.word.altAnswers ?? const <String>[])
      TextEditingController(text: alt),
  ];

  String? _error;
  bool _confirmingDelete = false;

  @override
  void dispose() {
    _viController.dispose();
    _krController.dispose();
    _hintController.dispose();
    for (final c in _altControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_viController.text.trim().isEmpty ||
        _krController.text.trim().isEmpty) {
      setState(
        () => _error = "Vui lòng nhập đủ nghĩa tiếng Việt và từ tiếng Hàn.",
      );
      return;
    }
    Navigator.of(context).pop(
      EditCardSaved(
        vi: _viController.text,
        kr: _krController.text,
        hint: _hintController.text,
        altAnswers: [for (final c in _altControllers) c.text],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;

    return AlertDialog(
      backgroundColor: p.cardBg,
      title: Text(
        "Sửa thẻ",
        style: GoogleFonts.notoSansKr(
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _label(p, "Nghĩa tiếng Việt"),
              _field(p, _viController),
              const SizedBox(height: 14),
              _label(p, "Từ tiếng Hàn (đáp án chính)"),
              _field(p, _krController, korean: true),
              const SizedBox(height: 14),
              _label(p, "Đáp án đúng khác (không bắt buộc)"),
              for (var i = 0; i < _altControllers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _field(p, _altControllers[i], korean: true),
                      ),
                      IconButton(
                        tooltip: "Xoá đáp án này",
                        onPressed: () => setState(() {
                          _altControllers.removeAt(i).dispose();
                        }),
                        icon: Icon(Icons.close, size: 18, color: p.wrong),
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                onPressed: () => setState(
                  () => _altControllers.add(TextEditingController()),
                ),
                icon: Icon(Icons.add, size: 16, color: p.blue),
                label: Text(
                  "Thêm đáp án đúng khác",
                  style: TextStyle(color: p.blue),
                ),
              ),
              const SizedBox(height: 8),
              _label(p, "Gợi ý (không bắt buộc)"),
              // Cao sẵn 3 dòng, giãn tới 5 dòng rồi cuộn bên trong — gợi ý
              // thật trong dữ liệu có cái dài hơn chục dòng (chiết tự Hán tự).
              _field(p, _hintController, minLines: 3, maxLines: 5),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: p.wrong, fontSize: 13)),
              ],
              const Divider(height: 32),
              if (!_confirmingDelete)
                TextButton.icon(
                  onPressed: () => setState(() => _confirmingDelete = true),
                  icon: Icon(Icons.delete_outline, size: 18, color: p.wrong),
                  label: Text("Xoá thẻ này", style: TextStyle(color: p.wrong)),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Xoá thẻ này khỏi bộ từ? Các thẻ ngữ cảnh nối sau nó cũng bị xoá theo.",
                      style: TextStyle(color: p.inkSoft, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(const EditCardDeleted()),
                          child: Text("Xoá", style: TextStyle(color: p.wrong)),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _confirmingDelete = false),
                          child: Text(
                            "Huỷ",
                            style: TextStyle(color: p.inkSoft),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Huỷ", style: TextStyle(color: p.inkSoft)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: p.ink,
            foregroundColor: p.paper,
          ),
          child: const Text("Lưu"),
        ),
      ],
    );
  }

  Widget _label(AppPalette p, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: GoogleFonts.notoSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: p.inkSoft,
      ),
    ),
  );

  Widget _field(
    AppPalette p,
    TextEditingController controller, {
    bool korean = false,
    int minLines = 1,
    int maxLines = 1,
  }) {
    final field = TextField(
      controller: controller,
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
