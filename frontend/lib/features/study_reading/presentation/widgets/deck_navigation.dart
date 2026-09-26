import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/platform/platform.dart";
import "../../../../core/theme/app_palette.dart";
import "../../domain/review_schedule.dart";
import "../study_session_view_model.dart";
import "deck_editor_dialog.dart";

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
    if (group == null) return const SizedBox.shrink();
    final style = GoogleFonts.notoSans(fontSize: 12.5, color: p.blue);
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 4,
        children: [
          TextButton(
            onPressed: () => showDeckEditorDialog(
              context: context,
              palette: p,
              groupName: group.name,
              knownKorean: s.knownKorean,
              onSubmit: (name, words) =>
                  vm.createDeck(groupId: group.id, name: name, words: words),
            ),
            child: Text("+ Bộ mới", style: style),
          ),
          if (!s.isVirtualDeck && s.currentDeckId != null)
            TextButton(
              onPressed: () => showDeckEditorDialog(
                context: context,
                palette: p,
                groupName: group.name,
                knownKorean: s.knownKorean,
                appendTo: s.currentDeckName,
                onSubmit: (_, words) => vm.appendCards(s.currentDeckId!, words),
              ),
              child: Text("+ Thêm từ vào bộ này", style: style),
            ),
        ],
      ),
    );
  }
}

/// Dropdown được điều khiển hoàn toàn bởi state của engine.
///
/// Cố tình không dùng [DropdownButtonFormField]: nó giữ giá trị riêng bên
/// trong FormFieldState, nên khi engine tự đổi deck (đổi nhóm từ vựng, xoá
/// thẻ) ô chọn sẽ hiển thị deck cũ — và nếu deck cũ không còn trong danh sách
/// thì Flutter ném assert.
class DeckPicker extends ConsumerWidget {
  const DeckPicker({super.key, required this.state, required this.palette});

  final StudySessionState state;
  final AppPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: p.paperLine),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButton<String>(
        value: state.currentDeckId,
        hint: Text("Chọn bộ từ", style: TextStyle(color: p.inkSoft)),
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: p.cardBg,
        style: GoogleFonts.notoSans(fontSize: 14, color: p.ink),
        items: [
          for (final o in state.deckOptions)
            DropdownMenuItem(
              value: o.id,
              enabled: o.enabled,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      o.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: o.enabled ? p.ink : p.inkSoft),
                    ),
                  ),
                  if (o.review case final r?)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        r.shortLabel,
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          color: r.state == ReviewState.due
                              ? p.gold
                              : p.inkSoft,
                          fontWeight: r.state == ReviewState.due
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
        onChanged: (id) {
          if (id != null) {
            ref.read(studySessionViewModelProvider.notifier).switchDeck(id);
          }
        },
      ),
    );
  }
}
