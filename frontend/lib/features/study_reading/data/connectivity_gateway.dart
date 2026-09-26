import "package:connectivity_plus/connectivity_plus.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "connectivity_gateway.g.dart";

/// Bọc `connectivity_plus` lại thành một giao diện tối giản — chỉ báo "vừa có
/// mạng trở lại", không lộ chi tiết loại kết nối (wifi/mobile/...) ra ngoài vì
/// view model không cần biết.
///
/// **Vì sao bọc thay vì gọi thẳng `Connectivity()` trong view model:** giống
/// `localStoreProvider`/`contentApiProvider`, cần override được trong test.
/// `Connectivity` dùng EventChannel — gọi thẳng trong `testWidgets` sẽ đụng
/// platform channel thật, đúng cái bẫy đã ghi trong docs/testing.md.
abstract class ConnectivityGateway {
  /// Phát ra khi thiết bị chuyển từ "không có mạng" sang "có mạng" — đúng thời
  /// điểm nên thử đẩy các thay đổi tích luỹ lúc offline lên server.
  Stream<void> get onReconnected;
}

class ConnectivityPlusGateway implements ConnectivityGateway {
  @override
  Stream<void> get onReconnected => Connectivity().onConnectivityChanged
      .where((results) => !results.contains(ConnectivityResult.none))
      .map((_) {});
}

@riverpod
ConnectivityGateway connectivityGateway(Ref ref) => ConnectivityPlusGateway();
