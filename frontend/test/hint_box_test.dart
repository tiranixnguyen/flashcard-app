import "package:flashcard_app/core/theme/app_palette.dart";
import "package:flashcard_app/core/theme/card_zoom_provider.dart";
import "package:flashcard_app/features/study_reading/presentation/widgets/hint_box.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:google_fonts/google_fonts.dart";

final _longHint = [
  for (var i = 1; i <= 12; i++) "dòng chú thích số $i",
].join("\n");
const _shortHint = "một dòng ngắn";

/// Chiều cao tối đa kỳ vọng trên máy tính: đúng [hintVisibleLines] dòng.
const _capHeight = 14.0 * 1.45 * hintVisibleLines;

/// Dựng giống ngữ cảnh thật trong thẻ: `IntrinsicHeight` + `Row` + cột nội
/// dung. `IntrinsicHeight` là chỗ dễ vỡ nhất (vd `LayoutBuilder` sẽ ném lỗi).
Future<void> pumpHint(WidgetTester tester, String hint) async {
  await tester.pumpWidget(
    // Bảng xem đầy đủ phóng chữ theo cardZoomProvider (SharedPreferences).
    ProviderScope(
      overrides: [cardZoomProvider.overrideWithValue(1.0)],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 600,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HintBox(
                            hint: hint,
                            title: "than phiền, bày tỏ",
                            palette: AppPalette.light,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(); // chờ post-frame đo tràn chữ (bản điện thoại)
}

Finder hintScrollbar() =>
    find.descendant(of: find.byType(HintBox), matching: find.byType(Scrollbar));

ScrollPosition hintScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(HintBox),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  group("máy tính / web", () {
    testWidgets("chú thích dài bị giới hạn chiều cao và cuộn được", (
      tester,
    ) async {
      await pumpHint(tester, _longHint);
      expect(tester.takeException(), isNull);

      expect(
        tester.getSize(find.byType(HintBox)).height,
        closeTo(_capHeight, 1),
      );
      expect(hintScrollbar(), findsOneWidget);
      expect(hintScroll(tester).maxScrollExtent, greaterThan(0));

      // Cuộn xuống thật để chắc là cuộn được, không chỉ "có thanh cuộn".
      await tester.drag(find.byType(HintBox), const Offset(0, -400));
      await tester.pump();
      expect(hintScroll(tester).pixels, greaterThan(0));

      // Không có kiểu "bấm xem đầy đủ" của điện thoại.
      expect(find.textContaining("Xem đầy đủ"), findsNothing);
    }, variant: TargetPlatformVariant.desktop());

    testWidgets("chú thích ngắn giữ nguyên chiều cao, không cuộn", (
      tester,
    ) async {
      await pumpHint(tester, _shortHint);
      expect(tester.getSize(find.byType(HintBox)).height, lessThan(_capHeight));
      expect(hintScroll(tester).maxScrollExtent, 0);
    }, variant: TargetPlatformVariant.desktop());
  });

  group("điện thoại", () {
    testWidgets(
      "chú thích dài bị cắt, bấm vào mở bảng xem đầy đủ",
      (tester) async {
        await pumpHint(tester, _longHint);
        expect(tester.takeException(), isNull);
        expect(find.text("Xem đầy đủ chú thích ›"), findsOneWidget);
        // Trên thẻ không cuộn được — chỉ cắt bớt.
        expect(hintScrollbar(), findsNothing);

        await tester.tap(find.byType(HintBox));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text("than phiền, bày tỏ"),
          ),
          findsOneWidget,
        );
        // Dòng cuối (bị cắt trên thẻ) phải có trong bảng xem đầy đủ.
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.textContaining("dòng chú thích số 12"),
          ),
          findsOneWidget,
        );
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );

    testWidgets(
      "chú thích ngắn không có 'xem đầy đủ', bấm vào không mở gì",
      (tester) async {
        await pumpHint(tester, _shortHint);
        expect(find.textContaining("Xem đầy đủ"), findsNothing);

        await tester.tap(find.byType(HintBox));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );
  });
}
