import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/theme/app_palette.dart";
import "../../data/audio_gateway.dart";
import "../../models/card_audio.dart";
import "../../models/study_word.dart";
import "../audio_playback.dart";
import "../study_session_view_model.dart";
import "audio_button.dart";
import "card_form_fields.dart";

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
  late final _form = CardForm(
    front: widget.word.front,
    back: widget.word.back,
    hint: widget.word.hint ?? "",
    note: widget.word.note ?? "",
    altAnswers: widget.word.altAnswers ?? const [],
    typeAnswer: widget.word.typeAnswer,
  );

  late CardAudio _audio = widget.word.audio;

  /// Trường đang tải file nghe lên (mỗi lúc một file).
  CardField? _uploading;

  String? _error;
  bool _confirmingDelete = false;

  @override
  void dispose() {
    _form.dispose();
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
    if (!_form.hasBothSides) {
      setState(() => _error = "Vui lòng nhập đủ mặt trước và mặt sau.");
      return;
    }
    // Nút nghe nằm cạnh chữ của trường; trường trống thì thẻ không hiện gì.
    for (final (field, controller) in [
      (CardField.hint, _form.hint),
      (CardField.note, _form.note),
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
        front: _form.front.text,
        back: _form.back.text,
        typeAnswer: _form.typeAnswer,
        hint: _form.hint.text,
        note: _form.note.text,
        altAnswers: [for (final c in _form.alts) c.text],
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
              CardFormFields(
                form: _form,
                palette: p,
                onChanged: () => setState(() {}),
                audioControl: (field) => _audioControl(p, field),
              ),
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
}
