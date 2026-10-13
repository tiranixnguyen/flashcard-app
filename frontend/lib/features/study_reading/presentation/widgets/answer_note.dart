import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/platform/platform.dart";
import "../../../../core/theme/app_palette.dart";
import "card_text_zoom.dart";
import "../../domain/note_format.dart";

/// Chiều cao tối đa của khung giải thích trên thẻ. Dài hơn thì trên máy
/// tính/web cuộn bên trong khung, trên điện thoại cắt bớt và bấm vào để xem
/// đầy đủ — giống [HintBox], để nút chấm bên dưới không bị đẩy khỏi màn hình.
/// Ở cỡ chữ gốc; chữ phóng to thì khung cao theo (xem [CardTextZoom]).
const answerNoteMaxHeight = 280.0;

/// Giải thích cho đáp án, hiện sau khi lộ mặt sau. Nội dung là Markdown dán
/// thẳng từ AI (tiêu đề, **đậm**, danh sách, bảng, code…).
///
/// Thẻ bọc trong `IntrinsicHeight` nên không dùng `LayoutBuilder` để đo tràn
/// (xem [HintBox]); thay vào đó đọc `maxScrollExtent` của khung cuộn sau khi
/// layout xong.
class AnswerNote extends StatefulWidget {
  const AnswerNote({
    super.key,
    required this.note,
    required this.title,
    required this.palette,
    this.headerTrailing,
  });

  final String note;

  /// Đặt cạnh tiêu đề "Giải thích" (nút nghe giải thích).
  final Widget? headerTrailing;

  /// Tiêu đề của bảng xem đầy đủ trên điện thoại (nghĩa tiếng Việt của thẻ).
  final String title;

  final AppPalette palette;

  @override
  State<AnswerNote> createState() => _AnswerNoteState();
}

class _AnswerNoteState extends State<AnswerNote> {
  final _scroll = ScrollController();
  bool _overflows = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    if (isPhone) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
    }
    // Khung cao theo cỡ chữ để phóng chữ vẫn thấy đủ số dòng như cũ.
    final maxHeight = MediaQuery.textScalerOf(
      context,
    ).scale(answerNoteMaxHeight);
    final box = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Scrollbar(
        controller: _scroll,
        // Luôn hiện thanh cuộn khi dài hơn khung (máy tính), để biết còn nội
        // dung bên dưới. Ngắn thì Scrollbar tự không vẽ gì.
        thumbVisibility: !isPhone,
        child: ScrollConfiguration(
          // Tắt thanh cuộn tự động của desktop, nếu không sẽ thành hai cái.
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            controller: _scroll,
            // Điện thoại: không cuộn lồng trong trang, bấm để mở bảng đầy đủ.
            physics: isPhone ? const NeverScrollableScrollPhysics() : null,
            padding: const EdgeInsets.only(right: 14),
            child: NoteMarkdown(note: widget.note, palette: p),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Giải thích",
              style: GoogleFonts.notoSans(fontSize: 13, color: p.inkSoft),
            ),
            if (widget.headerTrailing case final trailing?) ...[
              const SizedBox(width: 4),
              trailing,
            ],
          ],
        ),
        const SizedBox(height: 4),
        if (!isPhone)
          box
        else
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _overflows ? _openFull : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                box,
                if (_overflows) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Xem đầy đủ giải thích ›",
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.blue,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  void _checkOverflow() {
    if (!mounted || !_scroll.hasClients) return;
    final exceeded = _scroll.position.maxScrollExtent > 0;
    if (exceeded != _overflows) setState(() => _overflows = exceeded);
  }

  void _openFull() {
    final p = widget.palette;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: p.cardBg,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.notoSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 12),
                CardTextZoom(
                  child: NoteMarkdown(
                    note: widget.note,
                    palette: p,
                    selectable: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Markdown của giải thích, theo màu/font của app.
///
/// Chỉ dùng weight/style NotoSans đã bundle: đậm/tiêu đề là w600 (SemiBold),
/// nghiêng là file Italic — w700 sẽ khiến google_fonts đi tải mạng. Code cũng
/// dùng NotoSans (không bundle font monospace), phân biệt bằng nền.
class NoteMarkdown extends StatelessWidget {
  const NoteMarkdown({
    super.key,
    required this.note,
    required this.palette,
    this.selectable = false,
  });

  final String note;
  final AppPalette palette;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final base = GoogleFonts.notoSans(
      fontSize: 14.5,
      height: 1.5,
      color: p.ink,
    );
    TextStyle heading(double size) => base.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1.35,
    );
    final codeBg = p.paperLine.withValues(alpha: 0.45);

    return MarkdownBody(
      // Dán từ giao diện chat thường mất thụt lề danh sách — dựng lại cấp lồng.
      data: nestFlattenedLists(note),
      selectable: selectable,
      // Giữ xuống dòng đơn như khi dán (Markdown chuẩn sẽ nối thành một dòng)
      // — văn bản AI hay xuống dòng không kèm dòng trống.
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet(
        p: base,
        h1: heading(18),
        h2: heading(16.5),
        h3: heading(15.5),
        h4: heading(14.5),
        h5: heading(14.5),
        h6: heading(14.5),
        strong: const TextStyle(fontWeight: FontWeight.w600),
        em: const TextStyle(fontStyle: FontStyle.italic),
        del: const TextStyle(decoration: TextDecoration.lineThrough),
        a: TextStyle(color: p.blue, decoration: TextDecoration.underline),
        listBullet: base,
        listIndent: 22,
        blockSpacing: 8,
        code: base.copyWith(fontSize: 13.5, backgroundColor: codeBg),
        codeblockPadding: const EdgeInsets.all(10),
        codeblockDecoration: BoxDecoration(
          color: codeBg,
          borderRadius: BorderRadius.circular(4),
        ),
        blockquote: base.copyWith(color: p.inkSoft),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: p.paperLine, width: 3)),
        ),
        tableHead: const TextStyle(fontWeight: FontWeight.w600),
        tableBody: base,
        tableBorder: TableBorder.all(color: p.paperLine),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.paperLine)),
        ),
      ),
    );
  }
}
