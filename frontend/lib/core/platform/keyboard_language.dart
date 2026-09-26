import "dart:async";

import "package:flutter/services.dart";
import "package:flutter/widgets.dart";

import "platform.dart";

/// Ngôn ngữ bàn phím mong muốn cho ô nhập tiếng Hàn.
const koreanKeyboard = [Locale("ko")];

/// Tự chọn bàn phím đúng ngôn ngữ khi focus vào ô, rồi trả về bàn phím đang
/// dùng trước đó khi rời ô. Chỉ có tác dụng trên điện thoại:
///
/// - **Android:** do chính `TextField.hintLocales` lo (truyền [koreanKeyboard]
///   vào ô nhập). Bàn phím hỗ trợ `EditorInfo.hintLocales` (vd Gboard) sẽ tự
///   chuyển; có trả lại ngôn ngữ cũ khi rời ô hay không là do app bàn phím.
/// - **iOS:** Flutter không hỗ trợ `hintLocales`, nên widget này báo qua
///   MethodChannel cho code Swift trong `ios/Runner/AppDelegate.swift`
///   (`KeyboardLanguage`). iOS tự khôi phục bàn phím cũ khi rời ô.
/// - Máy tính / web: không làm gì — trình duyệt không cho trang web đổi bàn
///   phím, còn máy tính dùng bàn phím vật lý.
///
/// Bàn phím ngôn ngữ đó phải đã được bật trong Cài đặt của máy; chưa bật thì
/// giữ nguyên bàn phím hiện tại, không báo lỗi.
class KeyboardLanguageScope extends StatelessWidget {
  const KeyboardLanguageScope({
    super.key,
    required this.languageCode,
    required this.child,
  });

  /// Mã ngôn ngữ BCP-47, vd `"ko"`.
  final String languageCode;
  final Widget child;

  static const _channel = MethodChannel("flashcard/keyboard_language");

  @override
  Widget build(BuildContext context) {
    if (!isNativeIOS) return child;
    // Focus bọc ngoài chỉ để nghe "ô bên trong vừa được/mất focus"; bản thân
    // nó không nhận focus và không nằm trong thứ tự Tab.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) => unawaited(_notify(hasFocus)),
      child: child,
    );
  }

  Future<void> _notify(bool hasFocus) async {
    try {
      if (hasFocus) {
        await _channel.invokeMethod<void>("prefer", languageCode);
      } else {
        await _channel.invokeMethod<void>("clear");
      }
    } on PlatformException catch (e) {
      // Không có bàn phím này / engine đổi nội bộ: bỏ qua, gõ tay vẫn được.
      debugPrint("KeyboardLanguageScope: $e");
    } on MissingPluginException {
      // Chạy trên nền không có code native tương ứng — bỏ qua.
    }
  }
}
