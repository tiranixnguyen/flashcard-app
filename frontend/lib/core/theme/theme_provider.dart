import "dart:ui" show PlatformDispatcher;

import "package:flutter/material.dart" show Brightness;
import "package:riverpod_annotation/riverpod_annotation.dart";
import "package:shared_preferences/shared_preferences.dart";

import "app_palette.dart";

part "theme_provider.g.dart";

const _themePrefKey = "vocab-app-dark-mode";

@riverpod
class IsDarkMode extends _$IsDarkMode {
  /// Mặc định bám theo cài đặt sáng/tối của hệ điều hành (giống bản HTML dùng
  /// `prefers-color-scheme`), sau đó nếu người dùng từng tự chọn thì lấy lựa
  /// chọn đó đè lên.
  @override
  bool build() {
    _restoreSavedChoice();
    return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  }

  Future<void> _restoreSavedChoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_themePrefKey);
      if (saved != null) state = saved;
    } catch (_) {
      // Không đọc được cài đặt đã lưu -> cứ dùng theo hệ điều hành.
    }
  }

  Future<void> toggle() async {
    state = !state;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themePrefKey, state);
    } catch (_) {
      // Lần sau mở app sẽ quay về theo hệ điều hành; không đáng để báo lỗi.
    }
  }
}

@riverpod
AppPalette palette(Ref ref) {
  return ref.watch(isDarkModeProvider) ? AppPalette.dark : AppPalette.light;
}
