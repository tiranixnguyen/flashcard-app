import "package:flashcard_app/core/theme/app_palette.dart";
import "package:flashcard_app/core/theme/card_zoom_provider.dart";
import "package:flashcard_app/features/study_reading/presentation/widgets/answer_note.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:google_fonts/google_fonts.dart";

/// Giải thích dài kiểu AI trả về: tiêu đề, đậm, danh sách lồng, bảng, code.
final _longNote = [
  "## Cách dùng **가다**",
  "",
  "- nghĩa 1",
  "  - ví dụ lồng",
  "",
  "| Dạng | Nghĩa |",
  "|---|---|",
  "| 가요 | đi |",
  "",
  "```",
  "학교에 가요",
  "```",
  "",
  for (var i = 1; i <= 20; i++) "Dòng giải thích số $i",
].join("\n");
const _shortNote = "Dòng 1\nDòng 2 **đậm**";

/// Dựng trong `IntrinsicHeight` + `Row` + cột nội dung — ngữ cảnh khắt khe
/// nhất: Markdown (bảng, khối code cuộn ngang) phải layout được trong đó.
Future<void> pumpNote(WidgetTester tester, String note) async {
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
                          AnswerNote(
                            note: note,
                            title: "đi",
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
  await tester.pump(); // chờ post-frame đo tràn (bản điện thoại)
}

ScrollPosition noteScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(AnswerNote),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

const _phones = TargetPlatformVariant({
  TargetPlatform.android,
  TargetPlatform.iOS,
});

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets("hiện đúng định dạng: tiêu đề, bảng, code, xuống dòng đơn", (
    tester,
  ) async {
    await pumpNote(tester, _longNote);
    expect(tester.takeException(), isNull);
    expect(find.byType(Table), findsOneWidget);
    expect(find.textContaining("학교에 가요", findRichText: true), findsOneWidget);
    // Không có `##` / `**` thô: đã render thành Markdown.
    expect(find.textContaining("##", findRichText: true), findsNothing);
    expect(find.textContaining("**", findRichText: true), findsNothing);
  });

  testWidgets("xuống dòng đơn được giữ nguyên", (tester) async {
    await pumpNote(tester, _shortNote);
    expect(find.textContaining("Dòng 1\nDòng 2", findRichText: true), findsOne);
  });

  group("máy tính / web", () {
    testWidgets("dài thì giới hạn chiều cao và cuộn bên trong", (tester) async {
      await pumpNote(tester, _longNote);
      expect(noteScroll(tester).maxScrollExtent, greaterThan(0));
      await tester.drag(find.byType(AnswerNote), const Offset(0, -300));
      await tester.pump();
      expect(noteScroll(tester).pixels, greaterThan(0));
      expect(find.textContaining("Xem đầy đủ"), findsNothing);
    }, variant: TargetPlatformVariant.desktop());

    testWidgets("ngắn thì không cuộn", (tester) async {
      await pumpNote(tester, _shortNote);
      expect(noteScroll(tester).maxScrollExtent, 0);
    }, variant: TargetPlatformVariant.desktop());
  });

  group("điện thoại", () {
    testWidgets("dài thì cắt bớt, bấm mở bảng đầy đủ", (tester) async {
      await pumpNote(tester, _longNote);
      expect(tester.takeException(), isNull);
      expect(find.text("Xem đầy đủ giải thích ›"), findsOneWidget);

      await tester.tap(find.byType(AnswerNote));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.textContaining(
            "Dòng giải thích số 20",
            findRichText: true,
          ),
        ),
        findsWidgets,
      );
    }, variant: _phones);

    testWidgets("ngắn thì không có nút xem đầy đủ", (tester) async {
      await pumpNote(tester, _shortNote);
      expect(find.textContaining("Xem đầy đủ"), findsNothing);
    }, variant: _phones);
  });
}
