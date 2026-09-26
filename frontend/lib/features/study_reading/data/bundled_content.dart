import "dart:convert";

import "package:flutter/services.dart" show rootBundle;
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../models/content.dart";

part "bundled_content.g.dart";

const bundledContentPath = "assets/content.json";

/// Nội dung đóng gói sẵn trong app — cùng định dạng `GET /content`, xuất từ
/// DB bằng `npm run export-content` (backend). Chỉ dùng khi máy chưa từng tải
/// được nội dung từ server (cài mới + không có mạng); id trùng với server nên
/// lần học ghi lúc đó vẫn gửi lên đúng bộ.
class BundledContent {
  const BundledContent();

  Future<ContentSnapshot> load() async {
    final raw = await rootBundle.loadString(bundledContentPath);
    return ContentSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

@riverpod
BundledContent bundledContent(Ref ref) => const BundledContent();
