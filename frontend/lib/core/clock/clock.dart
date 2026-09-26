import "package:riverpod_annotation/riverpod_annotation.dart";

part "clock.g.dart";

/// Đồng hồ tiêm được — test override để cố định "hôm nay" khi kiểm tra gợi ý
/// ôn lại và thời điểm ghi lần học.
@riverpod
DateTime Function() clock(Ref ref) => DateTime.now;
