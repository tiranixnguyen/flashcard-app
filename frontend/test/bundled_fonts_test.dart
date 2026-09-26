import "package:flutter/services.dart" show AssetManifest, rootBundle;
import "package:flutter_test/flutter_test.dart";

/// Xác nhận đúng cơ chế mà `google_fonts` dùng để tìm font trong assets
/// (`AssetManifest.loadFromAssetBundle(rootBundle).listAssets()` rồi so khớp
/// hậu tố tên file) — không phải giả định suông. Nếu test này xanh, việc dò
/// font từ bundle của package sẽ tìm thấy đúng các file này mà không cần
/// mạng. Xem docs/frontend.md "Font tiếng Hàn" để biết vì sao phải bundle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("6 file font NotoSans/NotoSansKR có mặt trong AssetManifest", () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();

    const expected = [
      "NotoSans-Regular.ttf",
      "NotoSans-SemiBold.ttf",
      "NotoSans-Italic.ttf",
      "NotoSansKR-Regular.ttf",
      "NotoSansKR-SemiBold.ttf",
      "NotoSansKR-Bold.ttf",
    ];

    for (final filename in expected) {
      final found = assets.any((a) => a.endsWith(filename));
      expect(
        found,
        isTrue,
        reason:
            "Không thấy $filename trong AssetManifest — google_fonts sẽ rơi "
            "về tải mạng cho font này, đúng lỗi đang cố sửa.",
      );
    }
  });
}
