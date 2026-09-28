import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/platform/platform.dart";
import "../../../../core/theme/app_palette.dart";
import "../../data/content_api.dart";
import "../audio_playback.dart";

/// Nút ▶︎/⏸ phát một file nghe, kèm vòng tiến trình mỏng khi đang phát. Chỉ
/// phát khi bấm (không tự phát). Điện thoại chưa hỗ trợ nghe -> không hiện gì.
class AudioButton extends ConsumerWidget {
  const AudioButton({
    super.key,
    required this.audioId,
    required this.label,
    required this.palette,
    this.enabled = true,
  });

  final String audioId;

  /// Tên trường ("mặt sau"…) — tooltip là "Nghe <label>".
  final String label;
  final AppPalette palette;

  /// `false` khi biết chắc đang không có mạng (phát thẳng từ server).
  final bool enabled;

  static const size = 32.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isPhone) return const SizedBox.shrink();
    final p = palette;
    final url = ref.watch(contentApiProvider).audioUrl(audioId);
    final playback = ref.watch(audioPlaybackProvider);
    final active = playback.url == url;
    final failed = playback.failedUrl == url;
    final tick = playback.tick;
    final duration = tick.duration?.inMilliseconds ?? 0;

    final tooltip = !enabled
        ? "Cần có mạng để nghe"
        : failed
        ? "Không phát được — bấm để thử lại"
        : active && tick.playing
        ? "Tạm dừng"
        : "Nghe $label";

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (active)
            SizedBox.square(
              dimension: size - 2,
              child: CircularProgressIndicator(
                // Đang tải: vòng xoay; đang phát/dừng: tiến trình trong bài.
                value: tick.loading || duration == 0
                    ? null
                    : tick.position.inMilliseconds / duration,
                strokeWidth: 2,
                color: p.blue,
                backgroundColor: p.paperLine,
              ),
            ),
          IconButton(
            tooltip: tooltip,
            onPressed: enabled
                ? () => ref.read(audioPlaybackProvider.notifier).toggle(url)
                : null,
            padding: EdgeInsets.zero,
            iconSize: 20,
            constraints: const BoxConstraints.tightFor(
              width: size,
              height: size,
            ),
            icon: Icon(
              failed
                  ? Icons.error_outline
                  : active && tick.playing
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              // Tắt thì để theme tô màu disabled.
              color: !enabled
                  ? null
                  : failed
                  ? p.wrong
                  : p.blue,
            ),
          ),
        ],
      ),
    );
  }
}
