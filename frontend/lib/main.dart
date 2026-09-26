import "package:flashcard_app/features/study_reading/presentation/study_reading_view.dart";
import "package:flutter/foundation.dart"
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import "package:flutter/material.dart";
import "package:flutter/services.dart" show rootBundle;
import "package:flutter_riverpod/flutter_riverpod.dart";

import "core/theme/app_theme.dart";
import "core/theme/theme_provider.dart";

void main() {
  // Font NotoSans/NotoSansKR được đóng gói sẵn trong assets/fonts (xem
  // docs/frontend.md "Font tiếng Hàn") thay vì tải qua google_fonts lúc chạy — SIL
  // OFL yêu cầu đi kèm giấy phép, đăng ký vào trang "Licenses" chuẩn của
  // Flutter thay vì chỉ để file OFL.txt nằm im trong assets.
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString("assets/fonts/OFL.txt");
    yield LicenseEntryWithLineBreaks(["assets/fonts"], license);
  });

  runApp(const ProviderScope(child: FlashcardApp()));
}

class FlashcardApp extends ConsumerWidget {
  const FlashcardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final palette = ref.watch(paletteProvider);

    return MaterialApp(
      title: "Flashcard App",
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(palette, isDark: isDark),
      home: const StudyReadingView(),
    );
  }
}
