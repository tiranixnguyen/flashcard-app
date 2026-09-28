import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/platform/keyboard_language.dart";
import "../../../../core/theme/app_palette.dart";
import "../../data/audio_gateway.dart";
import "../../models/card_audio.dart";
import "../../models/study_word.dart";
import "../audio_playback.dart";
import "../study_session_view_model.dart";
import "audio_button.dart";

/// Kết quả người dùng chọn trong hộp thoại sửa thẻ.
sealed class EditCardResult {
  const EditCardResult();
}

class EditCardSaved extends EditCardResult {
  const EditCardSaved({
    required this.front,
    required this.back,
    required this.typeAnswer,
    this.hint,
    this.note,
    this.altAnswers = const [],
    this.audio = CardAudio.none,
  });

  final String front;
  final String back;
  final bool typeAnswer;
  final String? hint;
  final String? note;
  final List<String> altAnswers;

  /// File nghe từng trường sau khi sửa (đã tải lên server).
  final CardAudio audio;
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

class _EditCardDialog extends ConsumerStatefulWidget {
  const _EditCardDialog({required this.palette, required this.word});

  final AppPalette palette;
  final StudyWord word;

  @override
  ConsumerState<_EditCardDialog> createState() => _EditCardDialogState();
}

class _EditCardDialogState extends ConsumerState<_EditCardDialog> {
  late final _frontController = TextEditingController(text: widget.word.front);
  late final _backController = TextEditingController(text: widget.word.back);
  late bool _typeAnswer = widget.word.typeAnswer;
  late final _hintController = TextEditingController(
    text: widget.word.hint ?? "",
  );
  late final _noteController = TextEditingController(
    text: widget.word.note ?? "",
  );
  late final List<TextEditingController> _altControllers = [
    for (final alt in widget.word.altAnswers ?? const <String>[])
      TextEditingController(text: alt),
  ];

  late CardAudio _audio = widget.word.audio;

  /// Trường đang tải file nghe lên (mỗi lúc một file).
  CardField? _uploading;

  String? _error;
  bool _confirmingDelete = false;

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    _hintController.dispose();
    _noteController.dispose();
    for (final c in _altControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Chọn MP3 rồi tải lên ngay (cần mạng) — lưu thẻ chỉ gửi id. Huỷ dialog
  /// thì file đã tải thành mồ côi, backend có `prune-audio` dọn.
  Future<void> _pickAudio(CardField field) async {
    final picked = await ref.read(audioFilePickerProvider).pickMp3();
    if (picked == null || !mounted) return;
    setState(() {
      _uploading = field;
      _error = null;
    });
    final result = await ref
        .read(studySessionViewModelProvider.notifier)
        .uploadAudio(picked.bytes);
    if (!mounted) return;
    setState(() {
      _uploading = null;
      if (result.id case final id?) {
        _audio = _audio.withField(field, id);
      } else {
        _error = "Chưa tải được file nghe: ${result.error}";
      }
    });
  }

  /// Đóng dialog; dừng file đang nghe thử để tiếng không kéo dài sang màn học.
  void _close([EditCardResult? result]) {
    ref.read(audioPlaybackProvider.notifier).stop();
    Navigator.of(context).pop(result);
  }

  void _submit() {
    if (_frontController.text.trim().isEmpty ||
        _backController.text.trim().isEmpty) {
      setState(() => _error = "Vui lòng nhập đủ mặt trước và mặt sau.");
      return;
    }
    // Nút nghe nằm cạnh chữ của trường; trường trống thì thẻ không hiện gì.
    for (final (field, controller) in [
      (CardField.hint, _hintController),
      (CardField.note, _noteController),
    ]) {
      if (_audio[field] != null && controller.text.trim().isEmpty) {
        setState(
          () => _error =
              "Có file nghe ${field.label} thì cần nhập cả chữ — hoặc gỡ file.",
        );
        return;
      }
    }
    _close(
      EditCardSaved(
        front: _frontController.text,
        back: _backController.text,
        typeAnswer: _typeAnswer,
        hint: _hintController.text,
        note: _noteController.text,
        altAnswers: [for (final c in _altControllers) c.text],
        audio: _audio,
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
              _label(p, "Mặt trước — nghĩa tiếng Việt", audio: CardField.front),
              _field(p, _frontController),
              const SizedBox(height: 14),
              _label(
                p,
                "Mặt sau — tiếng Hàn (đáp án chính)",
                audio: CardField.back,
              ),
              _field(p, _backController, korean: true),
              const SizedBox(height: 6),
              CheckboxListTile(
                value: _typeAnswer,
                onChanged: (v) => setState(() => _typeAnswer = v ?? false),
                title: Text(
                  "Nhập đáp án",
                  style: GoogleFonts.notoSans(fontSize: 14, color: p.ink),
                ),
                subtitle: Text(
                  _typeAnswer
                      ? "Gõ mặt sau rồi chấm."
                      : "Thẻ tự chấm: lật thẻ rồi tự bấm Nhớ / Chưa nhớ.",
                  style: GoogleFonts.notoSans(fontSize: 12, color: p.inkSoft),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 8),
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
              _label(p, "Gợi ý (không bắt buộc)", audio: CardField.hint),
              // Cao sẵn 3 dòng, giãn tới 5 dòng rồi cuộn bên trong — gợi ý
              // thật trong dữ liệu có cái dài hơn chục dòng (chiết tự Hán tự).
              _field(p, _hintController, minLines: 3, maxLines: 5),
              const SizedBox(height: 14),
              _label(
                p,
                "Giải thích đáp án (không bắt buộc)",
                audio: CardField.note,
              ),
              Text(
                "Dán thẳng từ AI — giữ nguyên định dạng Markdown (tiêu đề, "
                "**đậm**, danh sách, bảng…). Hiện sau khi lộ đáp án.",
                style: GoogleFonts.notoSans(fontSize: 12, color: p.inkSoft),
              ),
              const SizedBox(height: 6),
              // Giải thích có thể rất dài: cao sẵn 4 dòng, giãn tới 12 dòng
              // rồi cuộn bên trong.
              _field(p, _noteController, minLines: 4, maxLines: 12),
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
                      "Xoá thẻ này khỏi bộ từ?",
                      style: TextStyle(color: p.inkSoft, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => _close(const EditCardDeleted()),
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
          onPressed: _close,
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

  /// Nhãn trường; có [audio] thì bên phải là nút gắn/nghe/gỡ file nghe.
  Widget _label(AppPalette p, String text, {CardField? audio}) {
    final label = Text(
      text,
      style: GoogleFonts.notoSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: p.inkSoft,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: audio == null
          ? label
          : Row(
              children: [
                Expanded(child: label),
                _audioControl(p, audio),
              ],
            ),
    );
  }

  Widget _audioControl(AppPalette p, CardField field) {
    if (_uploading == field) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: p.blue),
        ),
      );
    }
    final id = _audio[field];
    if (id == null) {
      return TextButton.icon(
        // Mỗi lúc tải một file — đỡ lẫn lỗi của file nào.
        onPressed: _uploading == null ? () => _pickAudio(field) : null,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          foregroundColor: p.blue,
        ),
        icon: const Icon(Icons.music_note_outlined, size: 16),
        label: Text(
          "Thêm file nghe",
          style: GoogleFonts.notoSans(fontSize: 12.5),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AudioButton(audioId: id, label: field.label, palette: p),
        IconButton(
          tooltip: "Gỡ file nghe ${field.label}",
          visualDensity: VisualDensity.compact,
          onPressed: () =>
              setState(() => _audio = _audio.withField(field, null)),
          icon: Icon(Icons.close, size: 16, color: p.wrong),
        ),
      ],
    );
  }

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
