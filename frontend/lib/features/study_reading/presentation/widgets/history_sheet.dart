import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/theme/app_palette.dart";
import "../../domain/review_schedule.dart";
import "../../models/study_session_record.dart";

/// Lịch sử các lần học một bộ (mọi máy), mới nhất trước, kèm gợi ý ôn lại.
Future<void> showHistorySheet({
  required BuildContext context,
  required AppPalette palette,
  required String deckName,
  required ReviewStatus review,
  required List<StudySessionRecord> history,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: palette.cardBg,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            deckName,
            style: GoogleFonts.notoSansKr(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reviewSummary(review),
            style: GoogleFonts.notoSans(fontSize: 13, color: palette.inkSoft),
          ),
          const SizedBox(height: 14),
          if (history.isEmpty)
            Text(
              "Chưa có lần học nào.",
              style: TextStyle(color: palette.inkSoft),
            )
          else
            for (final s in history) _row(palette, s),
        ],
      ),
    ),
  );
}

/// Một câu tóm tắt gợi ý ôn lại, dùng chung cho bảng lịch sử và màn hoàn thành.
String reviewSummary(ReviewStatus r) {
  final due = r.dueDay;
  return switch (r.state) {
    ReviewState.neverStudied =>
      "Chưa học hết bộ này lần nào — học hết một lượt để có lịch ôn.",
    _ when due != null =>
      "Lịch ôn: ${r.shortLabel} (${formatDay(due)}) · "
          "đã ôn tốt ${r.level}/${reviewIntervalsDays.length} lần liên tiếp",
    _ => r.shortLabel,
  };
}

String formatDay(DateTime d) {
  final l = d.toLocal();
  return "${l.day.toString().padLeft(2, "0")}/${l.month.toString().padLeft(2, "0")}";
}

String formatTime(DateTime d) {
  final l = d.toLocal();
  return "${l.hour.toString().padLeft(2, "0")}:${l.minute.toString().padLeft(2, "0")}";
}

const _deviceLabels = {
  "ios": "iPhone",
  "android": "Android",
  "macOS": "Mac",
  "macos": "Mac",
  "web": "Web",
};

Widget _row(AppPalette p, StudySessionRecord s) {
  final pct = (s.accuracy * 100).round();
  final minutes = s.endedAt.difference(s.startedAt).inMinutes;
  final good = s.accuracy >= goodAccuracy;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          child: Text(
            s.completed ? (good ? "✓" : "↺") : "…",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: !s.completed
                  ? p.inkSoft
                  : good
                  ? p.correct
                  : p.wrong,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${formatDay(s.endedAt)} ${formatTime(s.endedAt)} · "
                "${_deviceLabels[s.device] ?? s.device}",
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
              ),
              Text(
                "${s.completed ? "Học hết bộ" : "Học dở ${s.masteredCount}/${s.totalCards} thẻ"}"
                " · đúng ${s.correct}/${s.attempted} ($pct%)"
                "${minutes > 0 ? " · $minutes phút" : ""}",
                style: GoogleFonts.notoSans(fontSize: 12.5, color: p.inkSoft),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
