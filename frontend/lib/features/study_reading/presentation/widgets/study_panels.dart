import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/theme/app_palette.dart";
import "../study_session_view_model.dart";
import "history_sheet.dart";

/// Trái: lần học gần nhất + mở lịch sử (bộ thật). Phải: số liệu lượt này.
class StatsRow extends StatelessWidget {
  const StatsRow({super.key, required this.state, required this.palette});

  final StudySessionState state;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final s = state;
    final review = s.review;
    final last = review?.lastStudiedAt;
    return Row(
      children: [
        Expanded(
          child: review == null
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => showHistorySheet(
                      context: context,
                      palette: p,
                      deckName: s.currentDeckName ?? "",
                      review: review,
                      history: s.history,
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      last == null
                          ? "Lịch sử học"
                          : "Học lần cuối ${formatDay(last)} · Lịch sử",
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSans(
                        fontSize: 12.5,
                        color: p.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
        ),
        Text(
          "Đúng ${s.correctCount}/${s.attemptedCount}   ·   "
          "Thuộc ${s.masteredCount}/${s.totalCount}",
          textAlign: TextAlign.right,
          style: GoogleFonts.notoSansKr(fontSize: 13, color: p.inkSoft),
        ),
      ],
    );
  }
}

/// Máng chạy được vẽ bằng viền thay vì màu nền: `paperLine` trên `paper`
/// tương phản quá thấp nên ở mốc 0% thanh gần như biến mất.
class MasteryProgressBar extends StatelessWidget {
  const MasteryProgressBar({
    super.key,
    required this.progress,
    required this.palette,
  });

  final double progress;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        border: Border.all(color: palette.paperLine),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation(palette.gold),
          semanticsLabel: "Tiến độ thuộc từ",
          semanticsValue: "${(progress * 100).round()}%",
        ),
      ),
    );
  }
}

/// Hai hàng thay vì ba nút ngang: trên màn hình điện thoại, ba nút chia đều
/// chỉ còn ~110pt mỗi nút nên nhãn bị xuống dòng và cao thấp lệch nhau.
/// "Thẻ tiếp" được cho nguyên một hàng vì đây là thao tác lặp nhiều nhất và
/// nằm vừa tầm ngón cái.
class StudyControls extends ConsumerWidget {
  const StudyControls({super.key, required this.state, required this.palette});

  final StudySessionState state;
  final AppPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = palette;
    final s = state;
    final vm = ref.read(studySessionViewModelProvider.notifier);
    ButtonStyle style(Color color) => OutlinedButton.styleFrom(
      side: BorderSide(color: color, width: 1.5),
      foregroundColor: color,
      // Cố định chiều cao để hàng nút không nhảy khi nhãn đổi.
      minimumSize: const Size(0, 46),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: s.answered ? null : vm.markKnown,
                style: style(p.correct),
                child: const Text("✓ Đã thuộc"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: s.answered ? null : vm.revealAnswer,
                style: style(p.ink),
                child: const Text("Xem đáp án"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: s.answered && !s.nextLocked ? vm.nextCard : null,
            style: style(p.blue),
            child: Text(s.nextLocked ? "Thẻ tiếp (chờ…)" : "Thẻ tiếp →"),
          ),
        ),
      ],
    );
  }
}

class RestartFooter extends ConsumerWidget {
  const RestartFooter({super.key, required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.center,
      child: TextButton(
        onPressed: ref.read(studySessionViewModelProvider.notifier).restartDeck,
        child: Text(
          "Học lại bộ này từ đầu",
          style: GoogleFonts.notoSans(fontSize: 12.5, color: palette.inkSoft),
        ),
      ),
    );
  }
}

/// Màn "đã thuộc hết bộ": kết quả lượt này + lần ôn tiếp theo.
class CompletionView extends ConsumerWidget {
  const CompletionView({super.key, required this.state, required this.palette});

  final StudySessionState state;
  final AppPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = palette;
    final s = state;
    final review = s.review;
    final pct = s.attemptedCount == 0
        ? 100
        : (s.correctCount * 100 / s.attemptedCount).round();
    return Container(
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: p.paperLine),
      ),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
      child: Column(
        children: [
          Text(
            "🎉 Bạn đã thuộc hết bộ từ này!",
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansKr(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Lượt này đúng ${s.correctCount}/${s.attemptedCount} ($pct%).",
            textAlign: TextAlign.center,
            style: TextStyle(color: p.inkSoft),
          ),
          if (review != null && review.dueDay != null) ...[
            const SizedBox(height: 6),
            Text(
              "Lần sau: ${review.shortLabel} (${formatDay(review.dueDay!)})",
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                fontWeight: FontWeight.w600,
                color: p.gold,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: ref
                .read(studySessionViewModelProvider.notifier)
                .restartDeck,
            style: ElevatedButton.styleFrom(
              backgroundColor: p.ink,
              foregroundColor: p.paper,
            ),
            child: const Text("Học lại bộ này"),
          ),
        ],
      ),
    );
  }
}

/// Khung thông báo trống: nhóm chưa có bộ, bộ chưa có thẻ.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.palette,
    required this.title,
    required this.message,
  });

  final AppPalette palette;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      decoration: BoxDecoration(
        color: p.cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: p.paperLine),
      ),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 30),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansKr(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// Không nạp được dữ liệu lúc mở màn học — cho thử lại.
class LoadErrorView extends ConsumerWidget {
  const LoadErrorView({super.key, required this.error, required this.palette});

  final Object error;
  final AppPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = palette;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Không nạp được bộ từ vựng",
            style: GoogleFonts.notoSansKr(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "$error",
            textAlign: TextAlign.center,
            style: TextStyle(color: p.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => ref.invalidate(studySessionViewModelProvider),
            child: const Text("Thử lại"),
          ),
        ],
      ),
    );
  }
}
