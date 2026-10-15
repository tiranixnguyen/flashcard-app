import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/platform/platform.dart";
import "../../../../core/theme/app_palette.dart";
import "../../domain/review_schedule.dart";
import "../../models/deck.dart";
import "../study_session_view_model.dart";
import "deck_editor_dialog.dart";
import "linked_text.dart";

/// Tab chọn nhóm + (Mac/web) nút đổi tên / tạo nhóm.
class GroupTabs extends ConsumerWidget {
  const GroupTabs({super.key, required this.state, required this.palette});

  final StudySessionState state;
  final AppPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = palette;
    final s = state;
    final vm = ref.read(studySessionViewModelProvider.notifier);

    Widget action(String label, String tooltip, VoidCallback onPressed) =>
        Tooltip(
          message: tooltip,
          child: ActionChip(
            label: Text(label),
            onPressed: onPressed,
            backgroundColor: p.cardBg,
            side: BorderSide(color: p.paperLine),
            labelStyle: GoogleFonts.notoSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: p.blue,
            ),
          ),
        );
    final current = s.vocabGroups
        .where((g) => g.id == s.currentGroupId)
        .firstOrNull;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final g in s.vocabGroups)
          ChoiceChip(
            label: Text(g.name),
            selected: g.id == s.currentGroupId,
            onSelected: (_) => vm.switchVocabGroup(g.id),
            backgroundColor: p.cardBg,
            selectedColor: p.blue.withValues(alpha: 0.16),
            side: BorderSide(
              color: g.id == s.currentGroupId ? p.blue : p.paperLine,
            ),
            labelStyle: GoogleFonts.notoSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: g.id == s.currentGroupId ? p.blue : p.inkSoft,
            ),
          ),
        // Soạn nội dung chỉ trên Mac/web — điện thoại tập trung vào học.
        if (!isPhone) ...[
          if (current != null)
            action("✎", "Đổi tên nhóm “${current.name}”", () {
              showNameDialog(
                context: context,
                palette: p,
                title: "Đổi tên nhóm",
                confirmLabel: "Lưu",
                initial: current.name,
                onSubmit: (name) => vm.renameGroup(current.id, name),
              );
            }),
          action("+ Nhóm", "Tạo nhóm mới", () {
            showNameDialog(
              context: context,
              palette: p,
              title: "Tạo nhóm mới",
              confirmLabel: "Tạo",
              onSubmit: vm.createGroup,
            );
          }),
        ],
      ],
    );
  }
}

/// Hàng nút soạn nội dung dưới ô chọn bộ (chỉ Mac/web, cần có mạng).
class AuthoringRow extends ConsumerWidget {
  const AuthoringRow({super.key, required this.state, required this.palette});

  final StudySessionState state;
  final AppPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = palette;
    final s = state;
    final vm = ref.read(studySessionViewModelProvider.notifier);
    final group = s.vocabGroups
        .where((g) => g.id == s.currentGroupId)
        .firstOrNull;
    final deckId = s.currentDeckId;
    // Mọi nút ở đây chỉ dành cho bộ thật đang mở.
    if (group == null || s.isVirtualDeck || deckId == null) {
      return const SizedBox.shrink();
    }
    final style = GoogleFonts.notoSans(fontSize: 12.5, color: p.blue);
    // Căn phải, "Deck này" ngoài cùng.
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      spacing: 4,
      children: [
        TextButton(
          onPressed: () => showDeckEditorDialog(
            context: context,
            palette: p,
            groupName: group.name,
            knownKorean: s.knownKorean,
            appendTo: s.currentDeckName,
            onSubmit: (_, words, _, _) => vm.appendCards(deckId, words),
          ),
          child: Text("+ Thêm từ", style: style),
        ),
        TextButton.icon(
          onPressed: () => showDeckInfoDialog(
            context: context,
            palette: p,
            name: s.currentDeckName ?? "",
            type: s.currentDeckType,
            description: s.currentDeckDescription,
            onSubmit: (name, type, description) => vm.updateDeckInfo(
              deckId,
              name: name,
              type: type,
              description: description,
            ),
          ),
          icon: Icon(Icons.edit_note, size: 18, color: p.blue),
          label: Text("Deck này", style: style),
        ),
      ],
    );
  }
}

/// Mô tả bộ đang mở, ngay dưới ô chọn bộ (mọi máy). Link chỉ bấm được trên
/// Mac/web — điện thoại hiện như chữ thường.
class DeckDescription extends StatelessWidget {
  const DeckDescription({super.key, required this.text, required this.palette});

  final String text;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.notoSansKr(
      fontSize: 13.5,
      height: 1.45,
      color: palette.inkSoft,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
      child: isPhone
          ? Text(text, style: style)
          : LinkedText(text, style: style, linkColor: palette.blue),
    );
  }
}

/// Nhãn loại bộ nhỏ đặt trước tên bộ trong ô chọn.
class DeckTypeBadge extends StatelessWidget {
  const DeckTypeBadge({super.key, required this.type, required this.palette});

  final DeckType type;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: palette.blue.withValues(alpha: 0.5)),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      type.label,
      style: GoogleFonts.notoSansKr(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: palette.blue,
      ),
    ),
  );
}

/// Mở trình tạo bộ mới trong nhóm đang chọn (Mac/web, cần có mạng).
void showNewDeckDialog(
  BuildContext context,
  WidgetRef ref,
  StudySessionState s,
  AppPalette palette,
) {
  final group = s.vocabGroups
      .where((g) => g.id == s.currentGroupId)
      .firstOrNull;
  if (group == null) return;
  final vm = ref.read(studySessionViewModelProvider.notifier);
  showDeckEditorDialog(
    context: context,
    palette: palette,
    groupName: group.name,
    knownKorean: s.knownKorean,
    onSubmit: (name, words, type, description) => vm.createDeck(
      groupId: group.id,
      name: name,
      words: words,
      type: type,
      description: description,
    ),
  );
}

/// Ô chọn bộ, điều khiển hoàn toàn bởi state của engine.
///
/// Cố tình không dùng [DropdownButtonFormField]: nó giữ giá trị riêng bên
/// trong FormFieldState, nên khi engine tự đổi deck (đổi nhóm từ vựng, xoá
/// thẻ) ô chọn sẽ hiển thị deck cũ — và nếu deck cũ không còn trong danh sách
/// thì Flutter ném assert.
///
/// Không dùng [DropdownButton] vì menu của nó không có chỗ cho hàng cố định:
/// "+ Bộ mới" (Mac/web) phải dính ở đáy menu khi cuộn danh sách bộ. Menu là
/// overlay chứ không phải route — màn học hỏi [menuController] `isOpen` để
/// nhả phím tắt cho menu.
class DeckPicker extends ConsumerStatefulWidget {
  const DeckPicker({
    super.key,
    required this.state,
    required this.palette,
    required this.menuController,
  });

  final StudySessionState state;
  final AppPalette palette;
  final MenuController menuController;

  @override
  ConsumerState<DeckPicker> createState() => _DeckPickerState();
}

class _DeckPickerState extends ConsumerState<DeckPicker> {
  final _buttonFocus = FocusNode(debugLabel: "deck picker");

  @override
  void dispose() {
    _buttonFocus.dispose();
    super.dispose();
  }

  void _pick(String id) =>
      ref.read(studySessionViewModelProvider.notifier).switchDeck(id);

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final s = widget.state;
    final current = s.deckOptions
        .where((o) => o.id == s.currentDeckId)
        .firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        controller: widget.menuController,
        alignmentOffset: const Offset(0, 4),
        style: MenuStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          backgroundColor: WidgetStatePropertyAll(p.cardBg),
          side: WidgetStatePropertyAll(BorderSide(color: p.paperLine)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        menuChildren: [
          _DeckMenuPanel(
            width: constraints.maxWidth,
            state: s,
            palette: p,
            onPick: _pick,
            onNewDeck: isPhone
                ? null
                : () => showNewDeckDialog(context, ref, s, p),
          ),
        ],
        builder: (context, controller, _) => InkWell(
          focusNode: _buttonFocus,
          borderRadius: BorderRadius.circular(4),
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: Container(
            height: 48,
            padding: const EdgeInsets.only(left: 12, right: 4),
            decoration: BoxDecoration(
              border: Border.all(color: p.paperLine),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(
                  child: current == null
                      ? Text(
                          "Chọn bộ từ",
                          style: GoogleFonts.notoSans(
                            fontSize: 14,
                            color: p.inkSoft,
                          ),
                        )
                      : _DeckOptionRow(option: current, palette: p),
                ),
                Icon(Icons.arrow_drop_down, color: p.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Một dòng bộ: [nhãn loại] tên bộ … gợi ý ôn lại.
class _DeckOptionRow extends StatelessWidget {
  const _DeckOptionRow({required this.option, required this.palette});

  final DeckOption option;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final o = option;
    return Row(
      children: [
        if (o.type case final t?) DeckTypeBadge(type: t, palette: p),
        Expanded(
          child: Text(
            o.label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSans(
              fontSize: 14,
              color: o.enabled ? p.ink : p.inkSoft,
            ),
          ),
        ),
        if (o.review case final r?)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              r.shortLabel,
              style: GoogleFonts.notoSans(
                fontSize: 12,
                color: r.state == ReviewState.due ? p.gold : p.inkSoft,
                fontWeight: r.state == ReviewState.due
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }
}

/// Nội dung menu: danh sách bộ cuộn được, mở ra đã cuộn tới bộ đang chọn;
/// [onNewDeck] (Mac/web) là hàng "+ Bộ mới" dính ở đáy, không cuộn theo.
class _DeckMenuPanel extends StatefulWidget {
  const _DeckMenuPanel({
    required this.width,
    required this.state,
    required this.palette,
    required this.onPick,
    required this.onNewDeck,
  });

  final double width;
  final StudySessionState state;
  final AppPalette palette;
  final ValueChanged<String> onPick;
  final VoidCallback? onNewDeck;

  static const itemHeight = 44.0;

  @override
  State<_DeckMenuPanel> createState() => _DeckMenuPanelState();
}

class _DeckMenuPanelState extends State<_DeckMenuPanel> {
  static const _listPadding = 4.0;
  ScrollController? _scroll;

  /// Chiều cao tối đa của cả menu (danh sách + hàng "+ Bộ mới").
  double get _maxHeight =>
      (MediaQuery.sizeOf(context).height * 0.6).clamp(200.0, 480.0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scroll != null) return;
    final s = widget.state;
    final i = s.deckOptions.indexWhere((o) => o.id == s.currentDeckId);
    const h = _DeckMenuPanel.itemHeight;
    // Đưa bộ đang chọn vào giữa danh sách; ListView tự kẹp trong giới hạn.
    _scroll = ScrollController(
      initialScrollOffset: i <= 0 ? 0 : i * h - (_maxHeight - h) / 2,
    );
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final s = widget.state;
    final itemStyle = MenuItemButton.styleFrom(
      minimumSize: const Size.fromHeight(_DeckMenuPanel.itemHeight),
      maximumSize: const Size.fromHeight(_DeckMenuPanel.itemHeight),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
    // Kích thước cố định, tính trước: MenuAnchor đo intrinsic width của menu,
    // mà ListView (lazy) không trả lời được câu đó.
    const h = _DeckMenuPanel.itemHeight;
    final footerHeight = widget.onNewDeck == null ? 0.0 : h + 1;
    final listHeight = (s.deckOptions.length * h + 2 * _listPadding).clamp(
      h,
      _maxHeight - footerHeight,
    );
    return SizedBox(
      width: widget.width,
      height: listHeight + footerHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(vertical: _listPadding),
              itemExtent: _DeckMenuPanel.itemHeight,
              itemCount: s.deckOptions.length,
              itemBuilder: (_, i) {
                final o = s.deckOptions[i];
                final selected = o.id == s.currentDeckId;
                return MenuItemButton(
                  style: itemStyle.copyWith(
                    backgroundColor: WidgetStatePropertyAll(
                      selected
                          ? p.blue.withValues(alpha: 0.12)
                          : Colors.transparent,
                    ),
                  ),
                  onPressed: o.enabled ? () => widget.onPick(o.id) : null,
                  child: _DeckOptionRow(option: o, palette: p),
                );
              },
            ),
          ),
          if (widget.onNewDeck case final onNewDeck?) ...[
            Divider(height: 1, color: p.paperLine),
            MenuItemButton(
              style: itemStyle,
              onPressed: onNewDeck,
              child: Text(
                "+ Bộ mới",
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: p.blue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
