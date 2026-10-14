import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/platform/keyboard_language.dart";
import "../../../../core/platform/platform.dart";
import "../../../../core/theme/app_palette.dart";
import "../../domain/study_engine.dart";
import "../../models/card_audio.dart";
import "../study_session_view_model.dart";
import "answer_note.dart";
import "audio_button.dart";
import "card_text_zoom.dart";
import "dashed_line.dart";
import "edit_card_dialog.dart";
import "hint_box.dart";

/// Thẻ đang hỏi: trạng thái thẻ + menu •••, mặt trước, chú thích, rồi ô trả
/// lời (thẻ gõ đáp án) hoặc mặt sau lúc lật (thẻ tự chấm), phản hồi sau khi
/// trả lời, và giải thích đáp án (nếu có) khi đã lộ mặt sau. Trường nào có
/// file nghe thì có nút ▶︎ ngay cạnh (chỉ Mac/web). Ô nhập (controller/focus)
/// do màn học giữ vì phím tắt, tự cuộn và việc dọn ô khi sang thẻ mới đều cần
/// tới chúng.
class StudyCard extends ConsumerWidget {
  const StudyCard({
    super.key,
    required this.state,
    required this.palette,
    required this.narrow,
    required this.answerController,
    required this.answerFocus,
    this.answerRowKey,
  });

  final StudySessionState state;
  final AppPalette palette;

  /// Màn hẹp (< 400pt) — thu padding lại.
  final bool narrow;
  final TextEditingController answerController;
  final FocusNode answerFocus;

  /// Để màn học đo vị trí hàng trả lời khi tự cuộn.
  final Key? answerRowKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = palette;
    final s = state;
    final word = s.word!;
    final isCorrect =
        s.outcome == AnswerOutcome.correct || s.outcome == AnswerOutcome.known;

    return Container(
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: p.paperLine),
        boxShadow: [
          BoxShadow(
            color: p.ink.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(narrow ? 16 : 24, 26, narrow ? 16 : 24, 28),
      // Vạch đứt bên trái kéo hết chiều cao thẻ nhờ Positioned trong Stack.
      // Không dùng IntrinsicHeight + Row(stretch): lượt đo intrinsic lệch vài
      // phần pixel so với lúc xếp thật (TextField, font thật) làm cột tràn 1px.
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 6,
            child: DashedVerticalLine(color: p.red),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardMeta(state: s, palette: p),
                const SizedBox(height: 16),
                CardTextZoom(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Nghĩa tiếng Việt",
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          color: p.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _withAudio(
                        s,
                        CardField.front,
                        p,
                        Text(
                          word.front,
                          style: GoogleFonts.notoSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: p.ink,
                          ),
                        ),
                      ),
                      if (word.hint != null) ...[
                        const SizedBox(height: 12),
                        // Key theo thẻ để sang thẻ mới thì vị trí cuộn /
                        // trạng thái "tràn" được làm mới, không mang theo từ
                        // thẻ trước. Key phải khác của AnswerNote: trùng key
                        // thì element gợi ý cũ không được gỡ, vẫn hiện.
                        _withAudio(
                          s,
                          CardField.hint,
                          p,
                          HintBox(
                            key: ValueKey(("hint", s.cardSerial)),
                            hint: word.hint!,
                            title: word.front,
                            palette: p,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                if (word.typeAnswer) ...[
                  _answerRow(ref, isCorrect),
                  if (s.answered) ...[
                    const SizedBox(height: 14),
                    _Feedback(state: s, palette: p, isCorrect: isCorrect),
                  ],
                ] else if (s.answered)
                  // Thẻ tự chấm chỉ dừng lại ở đây sau "Đã thuộc" — tự
                  // chấm xong là sang thẻ tiếp luôn.
                  _Feedback(state: s, palette: p, isCorrect: isCorrect)
                else
                  _FlipSide(key: answerRowKey, state: s, palette: p),
                // Giải thích chỉ hiện khi đã lộ mặt sau (chấm xong / lật).
                if (word.note != null && (s.answered || s.flipped)) ...[
                  const SizedBox(height: 18),
                  CardTextZoom(
                    child: AnswerNote(
                      key: ValueKey(("note", s.cardSerial)),
                      note: word.note!,
                      title: word.front,
                      palette: p,
                      headerTrailing: _audioButton(s, CardField.note, p),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _answerRow(WidgetRef ref, bool isCorrect) {
    final p = palette;
    final vm = ref.read(studySessionViewModelProvider.notifier);
    return Row(
      key: answerRowKey,
      children: [
        Expanded(
          child: KeyboardLanguageScope(
            languageCode: "ko",
            child: CardTextZoom(
              child: TextField(
                controller: answerController,
                focusNode: answerFocus,
                // Android: bàn phím (vd Gboard) tự chuyển sang tiếng Hàn. iOS do
                // KeyboardLanguageScope lo — Flutter không hỗ trợ hintLocales ở iOS.
                hintLocales: koreanKeyboard,
                enabled: !state.answered,
                style: GoogleFonts.notoSansKr(
                  fontSize: 22,
                  color: isCorrect ? p.correct : p.ink,
                ),
                decoration: InputDecoration(
                  hintText: "Gõ tiếng Hàn…",
                  // Nhỏ hơn chữ người dùng gõ (22) để không bị cắt trên màn hẹp.
                  hintStyle: GoogleFonts.notoSans(
                    fontSize: 15,
                    color: p.inkSoft,
                  ),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: p.ink, width: 2),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: p.red, width: 2),
                  ),
                  disabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: isCorrect ? p.correct : p.ink,
                      width: 2,
                    ),
                  ),
                ),
                // Chỉ chấm bài: khi đã trả lời, ô này bị vô hiệu hoá nên không
                // bao giờ nhận Enter — sang thẻ tiếp do phím tắt ở màn học lo.
                onSubmitted: vm.checkAnswer,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: state.answered
              ? null
              : () => vm.checkAnswer(answerController.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: p.ink,
            foregroundColor: p.paper,
          ),
          child: const Text("Kiểm tra"),
        ),
      ],
    );
  }
}

/// Thẻ tự chấm: chưa lật thì là ô "chạm để lật" (điện thoại chạm thẳng vào
/// đây cho tiện ngón cái; nút "Lật thẻ" ở cụm nút bên dưới cũng làm được), lật
/// rồi thì hiện mặt sau kèm đáp án phụ.
class _FlipSide extends ConsumerWidget {
  const _FlipSide({super.key, required this.state, required this.palette});

  final StudySessionState state;
  final AppPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CardTextZoom(child: _content(ref));
  }

  Widget _content(WidgetRef ref) {
    final p = palette;
    final word = state.word!;
    if (!state.flipped) {
      return InkWell(
        onTap: ref.read(studySessionViewModelProvider.notifier).flipCard,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: p.paperLine, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isPhone
                ? "Nhớ đáp án trong đầu rồi chạm để lật thẻ"
                : "Nhớ đáp án trong đầu rồi lật thẻ (Space)",
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(fontSize: 14, color: p.inkSoft),
          ),
        ),
      );
    }
    final alts = word.altAnswers ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Đáp án",
          style: GoogleFonts.notoSans(fontSize: 13, color: p.inkSoft),
        ),
        const SizedBox(height: 4),
        _withAudio(
          state,
          CardField.back,
          p,
          Text(
            word.back,
            style: GoogleFonts.notoSansKr(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
        ),
        if (alts.isNotEmpty)
          Text(
            "(hoặc: ${alts.join(", ")})",
            style: GoogleFonts.notoSansKr(fontSize: 14, color: p.inkSoft),
          ),
      ],
    );
  }
}

/// Badge trạng thái thẻ, cờ ⭐/漢 và nút ••• (luôn sát mép phải).
class _CardMeta extends ConsumerWidget {
  const _CardMeta({required this.state, required this.palette});

  final StudySessionState state;
  final AppPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = palette;
    final s = state;
    return Row(
      children: [
        // Nhóm bên trái nằm trong Expanded để nút ••• luôn sát mép phải.
        // Không dùng Flexible(badge) + Spacer: hai cái cùng flex 1 nên Flutter
        // chia đôi phần trống, badge chỉ dùng bề rộng tự nhiên và phần thừa
        // trong suất của nó bị bỏ trống — nút ••• dừng ở ~64% bề ngang thẻ.
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: _badge(
                  s.isNewCard
                      ? "Thẻ mới"
                      : "Đang ôn · ${s.streak}/${s.masteryStreak} đúng liên tiếp",
                  gold: !s.isNewCard,
                ),
              ),
              // Trạng thái đánh dấu hiện ngay trên thẻ; trước đây phải mở
              // menu ••• mới biết thẻ đã được gắn cờ hay chưa.
              if (s.isMarked) _flagChip("★", p.gold, "Đã đánh dấu khó nhớ"),
              if (s.isHanja) _flagChip("漢", p.blue, "Đã đánh dấu Hán Hàn"),
              if (s.isPassage)
                _flagChip("📖", p.ink, "Đã đánh dấu đoạn văn ngắn"),
            ],
          ),
        ),
        CardZoomButton(palette: p),
        _menu(context, ref),
      ],
    );
  }

  Widget _badge(String text, {bool gold = false}) {
    final p = palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: gold ? p.gold : p.inkSoft),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: gold ? p.gold : p.inkSoft,
        ),
      ),
    );
  }

  Widget _flagChip(String glyph, Color color, String tooltip) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: tooltip,
        child: Text(
          glyph,
          style: GoogleFonts.notoSansKr(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, WidgetRef ref) {
    final p = palette;
    final s = state;
    final vm = ref.read(studySessionViewModelProvider.notifier);
    return PopupMenuButton<String>(
      color: p.cardBg,
      icon: Icon(Icons.more_horiz, color: p.inkSoft),
      tooltip: "Tuỳ chọn thẻ",
      onSelected: (value) async {
        switch (value) {
          case "mark":
            vm.toggleMark();
          case "hanja":
            vm.toggleHanja();
          case "passage":
            vm.togglePassage();
          case "edit":
            await _openEditDialog(context, vm);
        }
      },
      // Nhãn ngắn, không "Đánh dấu"; cờ đang bật thì có ✓ ở cuối.
      itemBuilder: (_) => [
        PopupMenuItem(
          value: "mark",
          child: Text(
            s.isMarked ? "★ Khó nhớ ✓" : "☆ Khó nhớ",
            style: TextStyle(color: s.isMarked ? p.gold : p.ink),
          ),
        ),
        PopupMenuItem(
          value: "hanja",
          child: Text(
            s.isHanja ? "漢 Hán Hàn ✓" : "漢 Hán Hàn",
            style: TextStyle(color: s.isHanja ? p.blue : p.ink),
          ),
        ),
        PopupMenuItem(
          value: "passage",
          child: Text(
            s.isPassage ? "📖 Đoạn văn ngắn ✓" : "📖 Đoạn văn ngắn",
            style: TextStyle(
              color: p.ink,
              fontWeight: s.isPassage ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        // Sửa/xoá thẻ cần mạng và bàn phím thật -> chỉ Mac/web.
        if (!isPhone)
          PopupMenuItem(
            value: "edit",
            child: Text("✎ Sửa / xoá thẻ", style: TextStyle(color: p.ink)),
          ),
      ],
    );
  }

  Future<void> _openEditDialog(
    BuildContext context,
    StudySessionViewModel vm,
  ) async {
    final word = state.word;
    if (word == null) return;
    final result = await showEditCardDialog(
      context: context,
      palette: palette,
      word: word,
    );
    if (!context.mounted || result == null) return;

    final error = switch (result) {
      EditCardSaved(
        :final front,
        :final back,
        :final typeAnswer,
        :final hint,
        :final note,
        :final altAnswers,
        :final audio,
      ) =>
        await vm.editCurrentCard(
          front: front,
          back: back,
          typeAnswer: typeAnswer,
          hint: hint,
          note: note,
          altAnswers: altAnswers,
          audio: audio,
        ),
      EditCardDeleted() => await vm.deleteCurrentCard(),
    };
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Chưa lưu được: $error")));
    }
  }
}

/// Gõ đúng: chỉ "✓ 맞아" (người học vừa gõ đúng, nhắc lại đáp án là thừa).
/// Sai/xem đáp án: "✕" + đáp án (kèm đáp án phụ) + nút "Đã trả lời đúng?"
/// (xem `canOverride`). Bấm nút đó: "✓ 맞아 — đáp án" — gõ chưa khớp nên vẫn
/// cần thấy đáp án chuẩn.
class _Feedback extends ConsumerWidget {
  const _Feedback({
    required this.state,
    required this.palette,
    required this.isCorrect,
  });

  final StudySessionState state;
  final AppPalette palette;
  final bool isCorrect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = palette;
    final word = state.word!;
    final alts = word.altAnswers ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardTextZoom(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCorrect ? "✓" : "✕",
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? p.correct : p.wrong,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (state.outcome == AnswerOutcome.correct &&
                          !state.overridden)
                        const TextSpan(text: "맞아")
                      else ...[
                        if (state.outcome == AnswerOutcome.known)
                          const TextSpan(text: "Đã đánh dấu thuộc — "),
                        if (state.overridden) const TextSpan(text: "맞아 — "),
                        TextSpan(
                          text: word.back,
                          style: GoogleFonts.notoSansKr(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (alts.isNotEmpty)
                          TextSpan(
                            text: "  (hoặc: ${alts.join(", ")})",
                            style: GoogleFonts.notoSansKr(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: p.inkSoft,
                            ),
                          ),
                      ],
                    ],
                  ),
                  style: GoogleFonts.notoSansKr(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isCorrect ? p.correct : p.wrong,
                  ),
                ),
              ),
              // Cả khi chỉ hiện "맞아" (không nhắc lại đáp án) vẫn nghe được.
              if (_audioButton(state, CardField.back, p)
                  case final button?) ...[
                const SizedBox(width: 8),
                button,
              ],
            ],
          ),
        ),
        if (state.canOverride) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: ref
                .read(studySessionViewModelProvider.notifier)
                .overrideAsCorrect,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              "Đã trả lời đúng?",
              style: GoogleFonts.notoSans(
                fontSize: 14,
                decoration: TextDecoration.underline,
                color: p.blue,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Nút nghe [field] của thẻ đang hỏi; `null` nếu trường đó không có file nghe.
Widget? _audioButton(StudySessionState s, CardField field, AppPalette p) {
  final id = s.word?.audio[field];
  if (id == null) return null;
  return AudioButton(
    audioId: id,
    label: field.label,
    palette: p,
    // Phát thẳng từ server: biết chắc mất mạng thì tắt nút, đỡ bấm rồi lỗi.
    enabled: s.syncStatus != SyncStatus.offline,
  );
}

/// [child] kèm nút nghe [field] bên phải (nếu trường đó có file nghe).
Widget _withAudio(
  StudySessionState s,
  CardField field,
  AppPalette p,
  Widget child,
) {
  final button = _audioButton(s, field, p);
  if (button == null) return child;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: child),
      const SizedBox(width: 8),
      button,
    ],
  );
}
