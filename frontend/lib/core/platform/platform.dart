import "package:flutter/foundation.dart"
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Điện thoại = iOS/Android, kể cả trình duyệt trên điện thoại (trên web,
/// `defaultTargetPlatform` phản ánh hệ điều hành của trình duyệt).
bool get isPhone =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.android;

/// Tên nền tảng ghi kèm mỗi lần học ("ios", "android", "macos", "web", …).
String get deviceName => kIsWeb ? "web" : defaultTargetPlatform.name;

/// App iOS native (không phải web chạy trên iPhone) — nơi có code Swift riêng
/// trong `ios/Runner/AppDelegate.swift`.
bool get isNativeIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
