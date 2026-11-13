import "package:flutter/material.dart";
import "package:flutter/services.dart" show Clipboard, ClipboardData;
import "package:google_fonts/google_fonts.dart";

import "../../../../core/theme/app_palette.dart";
import "../../domain/deck_import.dart";
import "../../models/deck.dart";
import "card_form_fields.dart";

/// Gửi lên server; trả về thông báo lỗi, `null` nếu thành công. [type],
/// [source] và [description] luôn `null` khi thêm từ vào bộ có sẵn.
typedef DeckSubmit =
    Future<String?> Function(
      String name,
      List<Map<String, dynamic>> words,
      DeckType? type,
      DeckSource? source,
      String? description,
    );

/// Giới hạn mô tả bộ — khớp `MAX_DESCRIPTION` ở backend.
const maxDeckDescription = 500;

/// Tạo bộ mới (có ô tên) hoặc thêm từ vào bộ có sẵn ([appendTo] = tên bộ).
/// Hai cách nhập từ: gõ tay từng từ, hoặc dán JSON từ AI rồi tick chọn từ nào
/// được lưu. Mọi từ mặc định là thẻ gõ đáp án (JSON ghi rõ `typeAnswer` thì
/// giữ). Chỉ Mac/web, cần có mạng.
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

/// Cách nhập từ trong trình tạo bộ.
enum _InputMode { json, manual }

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
  final _descriptionController = TextEditingController();

  /// Form "Nhập tay" — cùng các ô với dialog sửa thẻ.
  final _form = CardForm();

  var _mode = _InputMode.json;
  DeckImport _parsed = const DeckImport();

  /// Song song với [DeckImport.words]: từ nào được lưu (mặc định chọn hết).
  List<bool> _selected = const [];

  DeckType? _type;
  DeckSource? _source;
  bool _nameTouched = false;
  bool _sending = false;
  String? _error;

  bool get _isAppend => widget.appendTo != null;

  @override
  void dispose() {
    _nameController.dispose();
    _jsonController.dispose();
    _descriptionController.dispose();
    _form.dispose();
    super.dispose();
  }

  void _onJsonChanged(String text) {
    final parsed = parseDeckImport(text);
    setState(() {
      _parsed = parsed;
      _selected = List.filled(parsed.words.length, true);
      _error = null;
      // Lấy tên AI đặt nếu người dùng chưa tự gõ tên.
      if (!_isAppend && !_nameTouched && parsed.name != null) {
        _nameController.text = parsed.name!;
      }
    });
  }

  /// Từ trong form (đủ hai mặt), `null` nếu chưa đủ. Giải thích
  /// giữ nguyên Markdown (server tự dọn hai đầu), đáp án phụ server lọc trùng.
  Map<String, dynamic>? get _draftWord {
    final f = _form;
    if (!f.hasBothSides) return null;
    final hint = f.hint.text.trim();
    final alts = [
      for (final c in f.alts)
        if (c.text.trim().isNotEmpty) c.text.trim(),
    ];
    return {
      "front": f.front.text.trim(),
      "back": f.back.text.trim(),
      "typeAnswer": f.typeAnswer,
      if (hint.isNotEmpty) "hint": hint,
      if (f.note.text.trim().isNotEmpty) "note": f.note.text,
      if (alts.isNotEmpty) "altAnswers": alts,
    };
  }

  /// Những từ sẽ gửi đi. Gõ tay: mỗi lần một từ (nhiều từ thì dán JSON).
  List<Map<String, dynamic>> get _words => switch (_mode) {
    _InputMode.manual => [?_draftWord],
    _InputMode.json => [
      for (var i = 0; i < _parsed.words.length; i++)
        if (_selected[i]) _parsed.words[i],
    ],
  };

  bool get _canSubmit =>
      !_sending &&
      (_mode == _InputMode.manual || _parsed.errors.isEmpty) &&
      _words.isNotEmpty &&
      (_isAppend || _nameController.text.trim().isNotEmpty);

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final err = await widget.onSubmit(
      _nameController.text.trim(),
      _words,
      _type,
      _source,
      _isAppend ? null : _descriptionController.text,
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
    final count = _words.length;

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
                _label(p, "Loại bộ (không bắt buộc)"),
                DeckTypeChips(
                  palette: p,
                  selected: _type,
                  onChanged: _sending ? null : (t) => setState(() => _type = t),
                ),
                const SizedBox(height: 14),
                _label(p, "Tài liệu (không bắt buộc)"),
                DeckSourceChips(
                  palette: p,
                  selected: _source,
                  onChanged: _sending
                      ? null
                      : (s) => setState(() => _source = s),
                ),
                const SizedBox(height: 14),
                _label(p, "Mô tả ngắn (không bắt buộc, link bấm được)"),
                _DescriptionField(
                  controller: _descriptionController,
                  palette: p,
                ),
                const SizedBox(height: 14),
              ],
              SegmentedButton<_InputMode>(
                segments: const [
                  ButtonSegment(
                    value: _InputMode.json,
                    icon: Icon(Icons.data_object, size: 16),
                    label: Text("Dán JSON"),
                  ),
                  ButtonSegment(
                    value: _InputMode.manual,
                    icon: Icon(Icons.edit_outlined, size: 16),
                    label: Text("Nhập tay"),
                  ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: _sending
                    ? null
                    : (m) => setState(() {
                        _mode = m.single;
                        _error = null;
                      }),
              ),
              const SizedBox(height: 14),
              ...switch (_mode) {
                _InputMode.manual => _manualInput(p),
                _InputMode.json => _jsonInput(p),
              },
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
                ? "Thêm"
                : "Tạo bộ ($count thẻ)",
          ),
        ),
      ],
    );
  }

  List<Widget> _manualInput(AppPalette p) {
    final back = _draftWord?["back"] as String?;
    return [
      CardFormFields(
        form: _form,
        palette: p,
        enabled: !_sending,
        onChanged: () => setState(() => _error = null),
        onSubmitted: () {
          if (_canSubmit) _submit();
        },
      ),
      if (back != null && widget.knownKorean.contains(back)) ...[
        const SizedBox(height: 6),
        _dupWarning(p, [back]),
      ],
    ];
  }

  List<Widget> _jsonInput(AppPalette p) => [
    Row(
      children: [
        Expanded(child: _label(p, "JSON từ vựng (dán kết quả từ AI)")),
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
    _jsonPreview(p),
  ];

  Widget _jsonPreview(AppPalette p) {
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
    final cards = _parsed.words;
    if (cards.isEmpty) {
      return Text("Chưa có từ nào.", style: style);
    }
    final picked = _selected.where((v) => v).length;
    final allPicked = picked == cards.length;
    final dups = [
      for (var i = 0; i < cards.length; i++)
        if (_selected[i] && widget.knownKorean.contains(cards[i]["back"]))
          cards[i]["back"] as String,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "✓ Lưu $picked/${cards.length} từ — tick để chọn từ được lưu",
                style: style.copyWith(color: p.correct),
              ),
            ),
            TextButton(
              onPressed: _sending
                  ? null
                  : () => setState(
                      () => _selected = List.filled(cards.length, !allPicked),
                    ),
              child: Text(
                allPicked ? "Bỏ chọn hết" : "Chọn hết",
                style: TextStyle(color: p.blue, fontSize: 12.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _cardList(p, cards),
        if (dups.isNotEmpty) _dupWarning(p, dups),
      ],
    );
  }

  Widget _dupWarning(AppPalette p, List<String> dups) => Text(
    "Đã có sẵn trong các bộ khác (vẫn thêm được): ${dups.join(", ")}",
    style: GoogleFonts.notoSansKr(fontSize: 12.5, color: p.gold),
  );

  static const _cardRowHeight = 36.0;

  /// Mỗi thẻ một dòng: ô tick "lưu từ này" + mặt trước → mặt sau. Thẻ ghi
  /// rõ `typeAnswer: false` thì ghi chú "tự chấm".
  Widget _cardList(AppPalette p, List<Map<String, dynamic>> cards) {
    return Container(
      height: (cards.length * _cardRowHeight).clamp(0, 6 * _cardRowHeight),
      decoration: BoxDecoration(border: Border.all(color: p.paperLine)),
      child: ListView.builder(
        itemCount: cards.length,
        itemExtent: _cardRowHeight,
        itemBuilder: (_, i) {
          final c = cards[i];
          final selfGraded = c["typeAnswer"] == false ? "  · tự chấm" : "";
          return Row(
            children: [
              Tooltip(
                message: "Lưu từ này",
                child: Checkbox(
                  value: _selected[i],
                  visualDensity: VisualDensity.compact,
                  onChanged: _sending
                      ? null
                      : (v) => setState(() => _selected[i] = v ?? false),
                ),
              ),
              Expanded(
                child: Text(
                  "${c["front"]} → ${c["back"]}$selfGraded",
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

/// Ô nhập mô tả bộ (dùng chung khi tạo bộ và sửa bộ).
class _DescriptionField extends StatelessWidget {
  const _DescriptionField({required this.controller, required this.palette});

  final TextEditingController controller;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    minLines: 2,
    maxLines: 5,
    maxLength: maxDeckDescription,
    style: GoogleFonts.notoSansKr(fontSize: 14, color: palette.ink),
    decoration: _decoration(palette, "vd: Bài nghe sách Sơ cấp 1 — https://…"),
  );
}

/// Gửi thông tin bộ đã sửa; trả về thông báo lỗi, `null` nếu thành công.
typedef DeckInfoSubmit =
    Future<String?> Function(
      String name,
      DeckType? type,
      DeckSource? source,
      String description,
    );

/// "Deck này": sửa tên, loại, tài liệu, mô tả bộ đang mở (mô tả để trống là
/// xoá).
Future<bool?> showDeckInfoDialog({
  required BuildContext context,
  required AppPalette palette,
  required String name,
  required DeckType? type,
  required DeckSource? source,
  required String? description,
  required DeckInfoSubmit onSubmit,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _DeckInfoDialog(
      palette: palette,
      name: name,
      type: type,
      source: source,
      description: description ?? "",
      onSubmit: onSubmit,
    ),
  );
}

class _DeckInfoDialog extends StatefulWidget {
  const _DeckInfoDialog({
    required this.palette,
    required this.name,
    required this.type,
    required this.source,
    required this.description,
    required this.onSubmit,
  });

  final AppPalette palette;
  final String name;
  final DeckType? type;
  final DeckSource? source;
  final String description;
  final DeckInfoSubmit onSubmit;

  @override
  State<_DeckInfoDialog> createState() => _DeckInfoDialogState();
}

class _DeckInfoDialogState extends State<_DeckInfoDialog> {
  late final _name = TextEditingController(text: widget.name);
  late final _description = TextEditingController(text: widget.description);
  late DeckType? _type = widget.type;
  late DeckSource? _source = widget.source;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _canSubmit => !_sending && _name.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final err = await widget.onSubmit(
      _name.text.trim(),
      _type,
      _source,
      _description.text,
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

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final label = GoogleFonts.notoSans(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: p.inkSoft,
    );
    return AlertDialog(
      backgroundColor: p.cardBg,
      title: Text(
        "Sửa bộ “${widget.name}”",
        style: GoogleFonts.notoSansKr(
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Tên bộ", style: label),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              autofocus: true,
              enabled: !_sending,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              style: GoogleFonts.notoSans(fontSize: 15, color: p.ink),
              decoration: _decoration(p, "Tên bộ"),
            ),
            const SizedBox(height: 14),
            Text("Loại bộ (bấm lại loại đang chọn để bỏ)", style: label),
            const SizedBox(height: 6),
            DeckTypeChips(
              palette: p,
              selected: _type,
              onChanged: _sending ? null : (t) => setState(() => _type = t),
            ),
            const SizedBox(height: 14),
            Text("Tài liệu (bấm lại tài liệu đang chọn để bỏ)", style: label),
            const SizedBox(height: 6),
            DeckSourceChips(
              palette: p,
              selected: _source,
              onChanged: _sending ? null : (s) => setState(() => _source = s),
            ),
            const SizedBox(height: 14),
            Text("Mô tả ngắn", style: label),
            const SizedBox(height: 6),
            _DescriptionField(controller: _description, palette: p),
            Text(
              "Để trống là xoá mô tả. Link http(s):// bấm được khi học.",
              style: GoogleFonts.notoSans(fontSize: 12, color: p.inkSoft),
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
          onPressed: _canSubmit ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: p.ink,
            foregroundColor: p.paper,
          ),
          child: Text(_sending ? "Đang lưu…" : "Lưu"),
        ),
      ],
    );
  }
}

/// Hàng chip chọn loại bộ; bấm lại chip đang chọn = bỏ phân loại.
class DeckTypeChips extends StatelessWidget {
  const DeckTypeChips({
    super.key,
    required this.palette,
    required this.selected,
    required this.onChanged,
  });

  final AppPalette palette;
  final DeckType? selected;

  /// `null` = khoá (đang gửi).
  final ValueChanged<DeckType?>? onChanged;

  @override
  Widget build(BuildContext context) => _ChoiceChips(
    palette: palette,
    values: DeckType.values,
    labelOf: (t) => t.label,
    selected: selected,
    onChanged: onChanged,
  );
}

/// Hàng chip chọn tài liệu; bấm lại chip đang chọn = bỏ.
class DeckSourceChips extends StatelessWidget {
  const DeckSourceChips({
    super.key,
    required this.palette,
    required this.selected,
    required this.onChanged,
  });

  final AppPalette palette;
  final DeckSource? selected;

  /// `null` = khoá (đang gửi).
  final ValueChanged<DeckSource?>? onChanged;

  @override
  Widget build(BuildContext context) => _ChoiceChips(
    palette: palette,
    values: DeckSource.values,
    labelOf: (s) => s.label,
    selected: selected,
    onChanged: onChanged,
  );
}

/// Chọn tối đa một giá trị; bấm lại chip đang chọn = bỏ chọn (`null`).
class _ChoiceChips<T> extends StatelessWidget {
  const _ChoiceChips({
    required this.palette,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final AppPalette palette;
  final List<T> values;
  final String Function(T) labelOf;
  final T? selected;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(labelOf(v)),
            selected: v == selected,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            backgroundColor: p.cardBg,
            selectedColor: p.blue.withValues(alpha: 0.15),
            side: BorderSide(color: v == selected ? p.blue : p.paperLine),
            labelStyle: GoogleFonts.notoSansKr(
              fontSize: 13,
              color: v == selected ? p.blue : p.ink,
              fontWeight: v == selected ? FontWeight.w600 : FontWeight.w400,
            ),
            onSelected: onChanged == null
                ? null
                : (on) => onChanged!(on ? v : null),
          ),
      ],
    );
  }
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
