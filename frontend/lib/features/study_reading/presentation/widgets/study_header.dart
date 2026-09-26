import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/api/api_client.dart";
import "../../../../core/theme/app_palette.dart";
import "../../../../core/theme/theme_provider.dart";
import "../study_session_view_model.dart";

/// Tiêu đề + nút Tối/Sáng + dòng trạng thái đồng bộ.
class StudyHeader extends ConsumerWidget {
  const StudyHeader({
    super.key,
    required this.state,
    required this.palette,
    required this.isDark,
  });

  final StudySessionState state;
  final AppPalette palette;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "학습장  ",
                  style: GoogleFonts.notoSansKr(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                TextSpan(
                  text: "Học từ vựng tiếng Hàn",
                  style: GoogleFonts.notoSans(fontSize: 12, color: p.inkSoft),
                ),
              ],
            ),
          ),
        ),
        // Gộp nút Tối/Sáng và 2 dòng trạng thái lưu/đồng bộ thành một khối
        // canh phải riêng, KHÔNG kéo dãn chung cột với tiêu đề — nếu canh
        // phải trong cùng cột rộng bằng cả tiêu đề, text trạng thái trôi hẳn
        // sang xa bên phải, cách rời tiêu đề một khoảng trống lớn trông rất
        // rời rạc (bug đã gặp thực tế, xem ảnh chụp màn hình).
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () => ref.read(isDarkModeProvider.notifier).toggle(),
              icon: Icon(
                isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                size: 16,
                color: p.ink,
              ),
              label: Text(
                isDark ? "Sáng" : "Tối",
                style: TextStyle(color: p.ink),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: p.inkSoft),
              ),
            ),
            const SizedBox(height: 4),
            // Học luôn chạy trên dữ liệu trong máy; dòng này chỉ báo việc gửi
            // lần học + ⭐/漢 lên server (chạy nền, không chặn gì cả).
            // Tooltip chỉ địa chỉ server đang gọi — "Ngoại tuyến" trên điện
            // thoại thật thường là do quên --dart-define=API_BASE_URL.
            Tooltip(
              message: "Máy chủ: ${resolveBaseUrl()}",
              child: Text(
                _syncLabel(state),
                textAlign: TextAlign.right,
                style: GoogleFonts.notoSans(
                  fontSize: 11.5,
                  color: state.syncStatus == SyncStatus.error
                      ? p.wrong
                      : p.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _syncLabel(StudySessionState s) {
  final pending = s.pendingCount > 0 ? " · ${s.pendingCount} mục chờ gửi" : "";
  return switch (s.syncStatus) {
    SyncStatus.syncing => "⇅ Đang đồng bộ…",
    SyncStatus.synced when s.pendingCount == 0 => "✓ Đã đồng bộ",
    SyncStatus.offline => "📶 Ngoại tuyến$pending",
    SyncStatus.error => "⚠ Chưa đồng bộ được$pending",
    _ => pending.isEmpty ? "☁ Lưu trên máy" : "☁${pending.substring(2)}",
  };
}
