import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/theme/app_palette.dart";
import "../../../../core/theme/card_zoom_provider.dart";

/// Phóng chữ của [child] theo [cardZoomProvider], nhân thêm vào cỡ chữ của
/// hệ điều hành. Chỉ bọc vùng nội dung của thẻ (mặt trước/sau, gợi ý, ô trả
/// lời, phản hồi, giải thích) — nút và badge cố ý giữ cỡ gốc.
///
/// Bảng xem đầy đủ (bottom sheet) là route riêng, không thừa hưởng
/// `MediaQuery` của thẻ nên phải tự bọc lại.
class CardTextZoom extends ConsumerWidget {
  const CardTextZoom({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoom = ref.watch(cardZoomProvider);
    // Luôn bọc (kể cả 100%) để đổi nấc không làm cây widget đổi hình dạng —
    // nếu không ô trả lời bị dựng lại và mất focus.
    final system = MediaQuery.textScalerOf(context);
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(system.scale(1) * zoom)),
      child: child,
    );
  }
}

/// Nút "Aa" trên thẻ: mở bảng nhỏ A− · % · A+ · Mặc định. Bảng giữ nguyên khi
/// bấm −/+ để bấm liền nhiều nấc.
class CardZoomButton extends ConsumerWidget {
  const CardZoomButton({super.key, required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = palette;
    return MenuAnchor(
      style: MenuStyle(backgroundColor: WidgetStatePropertyAll(p.cardBg)),
      menuChildren: [_ZoomPanel(palette: p)],
      builder: (context, controller, _) => IconButton(
        tooltip: "Cỡ chữ trên thẻ (Cmd + / − / 0)",
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: Icon(Icons.format_size, color: p.inkSoft, size: 20),
      ),
    );
  }
}

class _ZoomPanel extends ConsumerWidget {
  const _ZoomPanel({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = palette;
    final zoom = ref.watch(cardZoomProvider);
    final vm = ref.read(cardZoomProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: "Chữ nhỏ hơn",
            onPressed: zoom > cardZoomLevels.first ? vm.zoomOut : null,
            icon: Icon(Icons.text_decrease, color: p.ink),
          ),
          SizedBox(
            width: 52,
            child: Text(
              "${(zoom * 100).round()}%",
              textAlign: TextAlign.center,
              style: TextStyle(color: p.ink, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: "Chữ to hơn",
            onPressed: zoom < cardZoomLevels.last ? vm.zoomIn : null,
            icon: Icon(Icons.text_increase, color: p.ink),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: zoom == 1.0 ? null : vm.reset,
            child: const Text("Mặc định"),
          ),
        ],
      ),
    );
  }
}
