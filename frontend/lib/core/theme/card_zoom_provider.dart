import "package:flutter/foundation.dart" show protected;
import "package:riverpod_annotation/riverpod_annotation.dart";
import "package:shared_preferences/shared_preferences.dart";

part "card_zoom_provider.g.dart";

const _zoomPrefKey = "vocab-app-card-zoom";

/// Các nấc phóng chữ, tăng dần. Đi theo danh sách thay vì cộng/trừ 0.1 để
/// không trôi số thực và để 85% vẫn quay về đúng 100%.
const cardZoomLevels = [0.85, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6];

/// Hệ số phóng chữ nội dung trên thẻ (1.0 = cỡ gốc), nhân thêm vào cỡ chữ
/// của hệ điều hành. Chỉ áp cho chữ trên thẻ — nút, header… giữ nguyên cỡ.
/// Lưu riêng từng máy, không đồng bộ.
///
/// keepAlive: màn hoàn thành không có thẻ nào watch; tự huỷ rồi dựng lại thì
/// thẻ sau hiện cỡ gốc một nhịp trước khi đọc xong cài đặt.
@Riverpod(keepAlive: true)
class CardZoom extends _$CardZoom {
  @override
  double build() {
    _restoreSavedZoom();
    return 1.0;
  }

  Future<void> _restoreSavedZoom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_zoomPrefKey);
      if (saved != null && cardZoomLevels.contains(saved)) state = saved;
    } catch (_) {
      // Không đọc được -> cỡ gốc.
    }
  }

  void zoomIn() =>
      _set(cardZoomLevels.firstWhere((l) => l > state, orElse: () => state));

  void zoomOut() =>
      _set(cardZoomLevels.lastWhere((l) => l < state, orElse: () => state));

  void reset() => _set(1.0);

  void _set(double value) {
    if (value == state) return;
    state = value;
    persist(value);
  }

  /// Tách riêng để widget test thay bằng bản không chạm SharedPreferences.
  @protected
  Future<void> persist(double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_zoomPrefKey, value);
    } catch (_) {
      // Lần sau mở app về cỡ gốc; không đáng để báo lỗi.
    }
  }
}
