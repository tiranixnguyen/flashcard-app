import "dart:io" show Platform;

import "package:dio/dio.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:riverpod_annotation/riverpod_annotation.dart";

part "api_client.g.dart";

/// Địa chỉ server chỉ định lúc build/chạy:
/// `fvm flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000`.
/// Bắt buộc với **điện thoại thật** — trên đó `localhost` là chính cái điện
/// thoại, nên không truyền thì app luôn báo "Ngoại tuyến".
const _baseUrlOverride = String.fromEnvironment("API_BASE_URL");

/// `10.0.2.2` chỉ có nghĩa bên trong máy ảo Android — nó là địa chỉ loopback
/// đặc biệt của máy ảo trỏ về `localhost` của máy host. Hard-code riêng giá
/// trị đó (như code cũ) làm mọi nền tảng khác (web, macOS, iOS simulator) gọi
/// nhầm sang chính nó và luôn timeout. `Platform.isAndroid` không tồn tại
/// trên web nên phải kiểm `kIsWeb` trước để tránh crash.
String resolveBaseUrl() {
  if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
  if (kIsWeb) return "http://localhost:3000";
  if (Platform.isAndroid) return "http://10.0.2.2:3000";
  return "http://localhost:3000";
}

@riverpod
Dio dio(Ref ref) {
  return Dio(
    BaseOptions(
      baseUrl: resolveBaseUrl(),
      connectTimeout: const Duration(seconds: 10),
      // Server nhận kết nối mà không trả lời thì request treo vô hạn — và vì
      // đồng bộ không chạy chồng, mọi lần đồng bộ sau cũng kẹt theo nó.
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
}
