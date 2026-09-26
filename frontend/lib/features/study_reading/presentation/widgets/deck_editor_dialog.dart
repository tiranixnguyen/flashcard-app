import "package:flutter/material.dart";
import "package:flutter/services.dart" show Clipboard, ClipboardData;
import "package:google_fonts/google_fonts.dart";

import "../../../../core/theme/app_palette.dart";
import "../../domain/deck_import.dart";

/// Gửi lên server; trả về thông báo lỗi, `null` nếu thành công.
typedef DeckSubmit =
    Future<String?> Function(String name, List<Map<String, dynamic>> words);

/// Tạo bộ mới (có ô tên) hoặc thêm từ vào bộ có sẵn ([appendTo] = tên bộ).
/// Dán JSON từ AI, xem trước số thẻ + từ trùng, chọn thẻ nào gõ đáp án
/// ("Nhập đáp án", tick sẵn cho đáp án ngắn), rồi gửi — cần có mạng.
Future<bool?> showDeckEditorDialog({
  required BuildContext context,
  required AppPalette palette,
  required String groupName,
  required Set<String> knownKorean,
  required DeckSubmit onSubmit,
  String? appendTo,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeckEditorDialog(
      palette: palette,
      groupName: groupName,
      knownKorean: knownKorean,
      onSubmit: onSubmit,
      appendTo: appendTo,
    ),
  );
}

class _DeckEditorDialog extends StatefulWidget {
  const _DeckEditorDialog({
    required this.palette,
    required this.groupName,
    required this.knownKorean,
    required this.onSubmit,
    this.appendTo,
  });

  final AppPalette palette;
  final String groupName;
  final Set<String> knownKorean;
  final DeckSubmit onSubmit;
  final String? appendTo;

  @override
  State<_DeckEditorDialog> createState() => _DeckEditorDialogState();
}

class _DeckEditorDialogState extends State<_DeckEditorDialog> {
  final _nameController = TextEditingController();
  final _jsonController = TextEditingController();
  DeckImport _parsed = const DeckImport();
  bool _nameTouched = false;
  bool _sending = false;
  String? _error;

  bool get _isAppend => widget.appendTo != null;

  @override
  void dispose() {
    _nameController.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  void _onJsonChanged(String text) {
    final parsed = parseDeckImport(text);
    setState(() {
      _parsed = parsed;
      _error = null;
      // Lấy tên AI đặt nếu người dùng chưa tự gõ tên.
      if (!_isAppend && !_nameTouched && parsed.name != null) {
        _nameController.text = parsed.name!;
      }
    });
  }

  bool get _canSubmit =>
      !_sending &&
      _parsed.ok &&
      (_isAppend || _nameController.text.trim().isNotEmpty);

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final err = await widget.onSubmit(
      _nameController.text.trim(),
      _parsed.words,
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _sending = false;
        _error = err;
      });
    }
  }

  Future<void> _copyPrompt() async {
    await Clipboard.setData(const ClipboardData(text: deckExtractionPrompt));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Đã chép prompt — dán vào claude.ai, thêm đoạn tiếng Hàn phía sau.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final dups = _parsed.duplicatesOf(widget.knownKorean);

    return AlertDialog(
      backgroundColor: p.cardBg,
      title: Text(
        _isAppend ? "Thêm từ vào “${widget.appendTo}”" : "Tạo bộ từ mới",
        style: GoogleFonts.notoSansKr(
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isAppend) ...[
                _label(p, "Tên bộ (nhóm ${widget.groupName})"),
                TextField(
                  controller: _nameController,
                  onChanged: (_) => setState(() => _nameTouched = true),
                  style: GoogleFonts.notoSans(fontSize: 15, color: p.ink),
                  decoration: _decoration(p, "vd: Bài 12 — Sức khoẻ"),
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Expanded(
                    child: _label(p, "JSON từ vựng (dán kết quả từ AI)"),
                  ),
                  TextButton.icon(
                    onPressed: _copyPrompt,
                    icon: Icon(Icons.copy, size: 15, color: p.blue),
                    label: Text(
                      "Sao chép prompt tách từ",
                      style: TextStyle(color: p.blue, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _jsonController,
                onChanged: _onJsonChanged,
                minLines: 8,
                maxLines: 14,
                style: GoogleFonts.notoSansKr(fontSize: 13, color: p.ink),
                decoration: _decoration(
                  p,
                  '{"name": "…", "words": [{"front": "răng", "back": "치아"}]}',
                ),
              ),
              const SizedBox(height: 10),
              _preview(p, dups),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: p.wrong, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text("Huỷ", style: TextStyle(color: p.inkSoft)),
        ),
        ElevatedButton(
          onPressed: _canSubmit ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: p.ink,
            foregroundColor: p.paper,
          ),
          child: Text(
            _sending
                ? "Đang lưu…"
                : _isAppend
                ? "Thêm ${_parsed.cardCount} thẻ"
                : "Tạo bộ",
          ),
        ),
      ],
    );
  }

  Widget _preview(AppPalette p, List<String> dups) {
    final style = GoogleFonts.notoSans(fontSize: 13, color: p.inkSoft);
    if (_parsed.errors.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in _parsed.errors.take(5))
            Text("⚠ $e", style: style.copyWith(color: p.wrong)),
          if (_parsed.errors.length > 5)
            Text("… và ${_parsed.errors.length - 5} lỗi khác", style: style),
        ],
      );
    }
    if (_parsed.words.isEmpty) {
      return Text("Chưa có từ nào.", style: style);
    }
    final cards = _parsed.cards;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "✓ ${_parsed.words.length} từ (${_parsed.cardCount} thẻ · "
          "${_parsed.typeAnswerCount} nhập đáp án, còn lại tự chấm)",
          style: style.copyWith(color: p.correct),
        ),
        const SizedBox(height: 6),
        Text(
          "☑ Nhập đáp án · ☐ tự chấm (lật thẻ rồi tự bấm Nhớ / Chưa nhớ)",
          style: style.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 4),
        _cardList(p, cards),
        if (dups.isNotEmpty)
          Text(
            "Đã có sẵn trong các bộ khác (vẫn thêm được): ${dups.join(", ")}",
            style: GoogleFonts.notoSansKr(fontSize: 12.5, color: p.gold),
          ),
      ],
    );
  }

  static const _cardRowHeight = 36.0;

  /// Mỗi thẻ một dòng: ô "Nhập đáp án" + mặt trước → mặt sau. Đổi ô tick là
  /// sửa thẳng `typeAnswer` trong [DeckImport.words] (thứ sẽ gửi lên server);
  /// sửa JSON thì đọc lại từ đầu, tick về mặc định.
  Widget _cardList(AppPalette p, List<Map<String, dynamic>> cards) {
    return Container(
      height: (cards.length * _cardRowHeight).clamp(0, 6 * _cardRowHeight),
      decoration: BoxDecoration(border: Border.all(color: p.paperLine)),
      child: ListView.builder(
        itemCount: cards.length,
        itemExtent: _cardRowHeight,
        itemBuilder: (_, i) {
          final c = cards[i];
          final back = c["back"] as String?;
          return Row(
            children: [
              Tooltip(
                message: "Nhập đáp án",
                child: Checkbox(
                  value: c["typeAnswer"] == true,
                  visualDensity: VisualDensity.compact,
                  onChanged: _sending
                      ? null
                      : (v) => setState(() => c["typeAnswer"] = v ?? false),
                ),
              ),
              Expanded(
                child: Text(
                  back == null ? c["front"] as String : "${c["front"]} → $back",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansKr(fontSize: 13, color: p.ink),
                ),
              ),
            ],
          );
        },
      ),
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
}

InputDecoration _decoration(AppPalette p, String hint) => InputDecoration(
  isDense: true,
  hintText: hint,
  hintStyle: TextStyle(color: p.inkSoft.withValues(alpha: 0.6)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: p.paperLine)),
  focusedBorder: OutlineInputBorder(
    borderSide: BorderSide(color: p.blue, width: 1.5),
  ),
);

/// Hộp thoại một ô tên (tạo nhóm / đổi tên nhóm). [onSubmit] trả về thông báo
/// lỗi, `null` nếu thành công.
Future<bool?> showNameDialog({
  required BuildContext context,
  required AppPalette palette,
  required String title,
  required String confirmLabel,
  required Future<String?> Function(String name) onSubmit,
  String initial = "",
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _NameDialog(
      palette: palette,
      title: title,
      confirmLabel: confirmLabel,
      onSubmit: onSubmit,
      initial: initial,
    ),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.palette,
    required this.title,
    required this.confirmLabel,
    required this.onSubmit,
    required this.initial,
  });

  final AppPalette palette;
  final String title;
  final String confirmLabel;
  final Future<String?> Function(String name) onSubmit;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final err = await widget.onSubmit(name);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _sending = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return AlertDialog(
      backgroundColor: p.cardBg,
      title: Text(
        widget.title,
        style: GoogleFonts.notoSansKr(
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              style: GoogleFonts.notoSans(fontSize: 15, color: p.ink),
              decoration: _decoration(p, "Tên nhóm"),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: p.wrong, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text("Huỷ", style: TextStyle(color: p.inkSoft)),
        ),
        ElevatedButton(
          onPressed: _sending || _controller.text.trim().isEmpty
              ? null
              : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: p.ink,
            foregroundColor: p.paper,
          ),
          child: Text(_sending ? "Đang lưu…" : widget.confirmLabel),
        ),
      ],
    );
  }
}
