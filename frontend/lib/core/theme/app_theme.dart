import "package:flutter/material.dart";

import "app_palette.dart";

/// Dựng [ThemeData] từ [AppPalette].
///
/// **Bắt buộc phải cấp theme cho `MaterialApp`.** Nếu không, mọi widget Material
/// sẽ lấy màu từ ThemeData *sáng* mặc định trong khi app tự vẽ nền tối — nút bị
/// vô hiệu hoá, dialog, SnackBar, con trỏ TextField đều trở thành đen-trên-đen.
ThemeData buildAppTheme(AppPalette p, {required bool isDark}) {
  final brightness = isDark ? Brightness.dark : Brightness.light;

  /// Màu chữ cho widget bị vô hiệu hoá. Mặc định của Material là
  /// `onSurface` 38%, quá mờ để đọc trên nền giấy tối.
  final disabled = p.inkSoft.withValues(alpha: 0.5);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.blue,
    onPrimary: p.cardBg,
    secondary: p.gold,
    onSecondary: p.cardBg,
    surface: p.cardBg,
    onSurface: p.ink,
    surfaceContainerHighest: p.paperLine,
    error: p.wrong,
    onError: p.cardBg,
    outline: p.paperLine,
  );

  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.paper,
    canvasColor: p.cardBg,
    dividerColor: p.paperLine,
    disabledColor: disabled,
    hintColor: p.inkSoft,
    iconTheme: IconThemeData(color: p.ink),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.red,
      selectionColor: p.blue.withValues(alpha: 0.3),
      selectionHandleColor: p.blue,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(disabledForegroundColor: disabled),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        disabledBackgroundColor: p.paperLine,
        disabledForegroundColor: disabled,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(disabledForegroundColor: disabled),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.cardBg),
    popupMenuTheme: PopupMenuThemeData(color: p.cardBg),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.gold),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(color: p.paper),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
