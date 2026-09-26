import "package:flutter/material.dart";
import "package:flutter/rendering.dart" show RenderParagraph;
import "package:google_fonts/google_fonts.dart";

import "../../../../core/platform/platform.dart";
import "../../../../core/theme/app_palette.dart";

/// Số dòng chú thích hiện sẵn trên thẻ. Dài hơn thì trên máy tính/web cuộn
/// bên trong khung, trên điện thoại cắt bớt và bấm vào để xem đầy đủ.
const hintVisibleLines = 5;

const _fontSize = 14.0;
const _lineHeight = 1.45;

/// Chú thích của thẻ, có giới hạn chiều cao.
///
/// Không dùng `LayoutBuilder` để đo xem chữ có tràn không: thẻ bọc trong
/// `IntrinsicHeight` (để vạch đứt bên trái kéo hết chiều cao thẻ), mà
/// `LayoutBuilder` không hỗ trợ tính intrinsic và sẽ ném lỗi. Thay vào đó đọc
/// `RenderParagraph.didExceedMaxLines` sau khi layout xong.
class HintBox extends StatefulWidget {
  const HintBox({
    super.key,
    required this.hint,
    required this.title,
    required this.palette,
  });

  final String hint;

  /// Tiêu đề của bảng xem đầy đủ trên điện thoại (nghĩa tiếng Việt của thẻ).
  final String title;

  final AppPalette palette;

  @override
  State<HintBox> createState() => _HintBoxState();
}

class _HintBoxState extends State<HintBox> {
  final _scroll = ScrollController();
  final _textKey = GlobalKey();
  bool _overflows = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  TextStyle get _style => GoogleFonts.notoSans(
    fontSize: _fontSize,
    height: _lineHeight,
    fontStyle: FontStyle.italic,
    color: widget.palette.inkSoft,
  );

  @override
  Widget build(BuildContext context) =>
      isPhone ? _buildPhone(context) : _buildDesktop(context);

  Widget _buildDesktop(BuildContext context) {
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(_fontSize) * _lineHeight;
    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: lineHeight * hintVisibleLines),
        child: Scrollbar(
          controller: _scroll,
          // Luôn hiện thanh cuộn khi chữ dài hơn khung, để người học biết còn
          // nội dung bên dưới. Chữ ngắn thì Scrollbar tự không vẽ gì.
          thumbVisibility: true,
          child: ScrollConfiguration(
            // Tắt thanh cuộn tự động của desktop, nếu không sẽ thành hai cái.
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.only(right: 14),
              child: Text(widget.hint, style: _style),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhone(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _overflows ? _openFullHint : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.hint,
            key: _textKey,
            style: _style,
            maxLines: hintVisibleLines,
            overflow: TextOverflow.ellipsis,
          ),
          if (_overflows) ...[
            const SizedBox(height: 6),
            Text(
              "Xem đầy đủ chú thích ›",
              style: GoogleFonts.notoSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.palette.blue,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _checkOverflow() {
    if (!mounted) return;
    final paragraph = _textKey.currentContext?.findRenderObject();
    final exceeded =
        paragraph is RenderParagraph && paragraph.didExceedMaxLines;
    if (exceeded != _overflows) setState(() => _overflows = exceeded);
  }

  void _openFullHint() {
    final p = widget.palette;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: p.cardBg,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
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
                SelectableText(
                  widget.hint,
                  style: _style.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
