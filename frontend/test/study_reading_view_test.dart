import "dart:async";
import "dart:convert";

import "package:flashcard_app/core/clock/clock.dart";
import "package:flashcard_app/core/theme/theme_provider.dart";
import "package:flashcard_app/features/study_reading/data/bundled_content.dart";
import "package:flashcard_app/features/study_reading/data/connectivity_gateway.dart";
import "package:flashcard_app/features/study_reading/data/content_api.dart";
import "package:flashcard_app/features/study_reading/data/local_store.dart";
import "package:flashcard_app/features/study_reading/models/content.dart";
import "package:flashcard_app/features/study_reading/models/study_session_record.dart";
import "package:flashcard_app/main.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart"
    show LogicalKeyboardKey, MethodCall, MethodChannel;
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:google_fonts/google_fonts.dart";

import "support/fixtures.dart";

/// Nội dung nhỏ, cố định — widget test chỉ kiểm tra phần ráp nối UI, còn
/// asset thật đã có `content_asset_test.dart` lo.
ContentSnapshot _content() => contentOf(
  [
    contentDeck("d1", const [
      {"kr": "학생", "vi": "học sinh"},
      {"kr": "학교", "vi": "trường học"},
    ], name: "Bộ Sep1"),
    contentDeck(
      "d2",
      const [
        {"kr": "사과", "vi": "quả táo"},
      ],
      groupId: "g2",
      name: "Bộ Sep2",
    ),
  ],
  groups: const [
    ContentGroup(id: "g1", name: "Sep1", position: 0),
    ContentGroup(id: "g2", name: "Sep2", position: 1),
  ],
);

final _now = DateTime(2026, 9, 25, 10);

/// Server giả trong bộ nhớ. Mặc định "không có mạng" — khớp môi trường test
/// và là nhánh an toàn nhất khi không test riêng đường đồng bộ.
class _FakeApi implements ContentApi {
  _FakeApi({this.online = false, ContentSnapshot? server})
    : server = server ?? _content();

  bool online;
  ContentSnapshot server;
  final pushedSessions = <StudySessionRecord>[];
  final pushedFlags = <FlagChange>[];
  final remoteSessions = <StudySessionRecord>[];
  var _n = 0;

  void _check() {
    if (!online) {
      throw const ApiException("Không kết nối được server.", offline: true);
    }
  }

  @override
  Future<ContentSnapshot> fetchContent() async {
    _check();
    return server;
  }

  @override
  Future<ContentGroup> createGroup(String name) async {
    _check();
    final g = ContentGroup(
      id: "gx${_n++}",
      name: name,
      position: server.groups.length,
    );
    server = server.upsertGroup(g);
    return g;
  }

  @override
  Future<ContentGroup> renameGroup(String groupId, String name) async {
    _check();
    final old = server.groups.firstWhere((g) => g.id == groupId);
    final g = ContentGroup(id: groupId, name: name, position: old.position);
    server = server.upsertGroup(g);
    return g;
  }

  @override
  Future<ContentDeck> createDeck({
    required String groupId,
    required String name,
    required List<Map<String, dynamic>> words,
  }) async {
    _check();
    final d = contentDeck(
      "dx${_n++}",
      words,
      groupId: groupId,
      name: name,
      position: 99,
    );
    server = server.upsertDeck(d);
    return d;
  }

  @override
  Future<ContentDeck> appendCards(
    String deckId,
    List<Map<String, dynamic>> words,
  ) async {
    _check();
    final old = server.decks.firstWhere((d) => d.id == deckId);
    final offset = old.cards.length;
    final extra = contentDeck(deckId, words).cards;
    String shift(String id) =>
        "$deckId-${int.parse(id.split("-").last) + offset}";
    final d = old.copyWith(
      cards: [
        ...old.cards,
        for (final c in extra)
          ContentCard(
            id: shift(c.id),
            position: c.position + offset,
            parentId: c.parentId == null ? null : shift(c.parentId!),
            kr: c.kr,
            vi: c.vi,
            hint: c.hint,
          ),
      ],
    );
    server = server.upsertDeck(d);
    return d;
  }

  @override
  Future<ContentCard> updateCard(
    String cardId, {
    required String kr,
    required String vi,
    String? hint,
    List<String> altAnswers = const [],
  }) async {
    _check();
    server = server.updateCard(
      cardId,
      (c) =>
          c.copyWith(kr: kr, vi: vi, hint: () => hint, altAnswers: altAnswers),
    );
    return server.decks
        .expand((d) => d.cards)
        .firstWhere((c) => c.id == cardId);
  }

  @override
  Future<void> deleteCard(String cardId) async {
    _check();
    server = server.removeCard(cardId);
  }

  @override
  Future<void> pushFlagChanges(List<FlagChange> changes) async {
    _check();
    pushedFlags.addAll(changes);
  }

  @override
  Future<void> pushSessions(List<StudySessionRecord> sessions) async {
    _check();
    pushedSessions.addAll(sessions);
    for (final s in sessions) {
      if (!remoteSessions.any((r) => r.id == s.id)) remoteSessions.add(s);
    }
  }

  @override
  Future<List<StudySessionRecord>> fetchSessions() async {
    _check();
    return [...remoteSessions];
  }
}

class _FakeBundled implements BundledContent {
  @override
  Future<ContentSnapshot> load() async => _content();
}

/// Ép chế độ tối mà không phải đọc SharedPreferences.
class _ForcedDarkMode extends IsDarkMode {
  @override
  bool build() => true;
}

/// Không đụng EventChannel thật của connectivity_plus; test tự bắn sự kiện
/// "có mạng trở lại" qua [reconnect].
class _FakeConnectivityGateway implements ConnectivityGateway {
  final _controller = StreamController<void>.broadcast();
  void reconnect() => _controller.add(null);

  @override
  Stream<void> get onReconnected => _controller.stream;
}

class _Harness {
  _Harness({required this.api, required this.kv, required this.connectivity});
  final _FakeApi api;
  final MemoryStore kv;
  final _FakeConnectivityGateway connectivity;

  LocalStore get store => LocalStore(kv);
}

void main() {
  setUp(() {
    // Không cho google_fonts gọi mạng trong test; dùng font dự phòng là đủ.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// Bơm frame tới khi thẻ đầu tiên hiện ra.
  ///
  /// Cố tình không dùng `pumpAndSettle`: trong lúc provider còn `loading`, màn
  /// hình có [CircularProgressIndicator] chạy vô hạn nên không bao giờ "settle".
  Future<_Harness> pumpApp(
    WidgetTester tester, {
    bool isDark = false,
    _FakeApi? api,
    MemoryStore? kv,
  }) async {
    final h = _Harness(
      api: api ?? _FakeApi(),
      kv: kv ?? MemoryStore(),
      connectivity: _FakeConnectivityGateway(),
    );
    await tester.pumpWidget(
      ProviderScope(
        // Mọi provider chạm I/O thật đều phải override — xem docs/testing.md.
        overrides: [
          bundledContentProvider.overrideWithValue(_FakeBundled()),
          localStoreProvider.overrideWithValue(LocalStore(h.kv)),
          contentApiProvider.overrideWithValue(h.api),
          connectivityGatewayProvider.overrideWithValue(h.connectivity),
          clockProvider.overrideWithValue(() => _now),
          if (isDark) isDarkModeProvider.overrideWith(_ForcedDarkMode.new),
        ],
        // Dùng chính [FlashcardApp] để test phủ luôn phần cấp ThemeData ở
        // main.dart, chứ không dựng một MaterialApp riêng cho test.
        child: const FlashcardApp(),
      ),
    );
    for (var i = 0; i < 40; i++) {
      if (find.text("Nghĩa tiếng Việt").evaluate().isNotEmpty) return h;
      await tester.pump(const Duration(milliseconds: 50));
    }
    final visible = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .toList();
    fail("Thẻ đầu tiên không hiện ra sau 2 giây. Đang hiển thị: $visible");
  }

  /// Cuộn tới rồi mới bấm — màn test 800×600 không chứa hết trang.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> tapKnown(WidgetTester tester) =>
      tapVisible(tester, find.widgetWithText(OutlinedButton, "✓ Đã thuộc"));

  Future<void> tapNext(WidgetTester tester) =>
      tapVisible(tester, find.widgetWithText(OutlinedButton, "Thẻ tiếp →"));

  /// Học hết bộ giả 2 thẻ bằng "Đã thuộc".
  Future<void> finishDeck(WidgetTester tester) async {
    for (var i = 0; i < 2; i++) {
      await tapKnown(tester);
      await tapNext(tester);
    }
    await tester.pump();
  }

  Future<void> openCardMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
  }

  const desktop = TargetPlatformVariant({
    TargetPlatform.macOS,
    TargetPlatform.windows,
  });

  testWidgets("hiện thẻ đầu tiên sau khi nạp xong bộ từ", (tester) async {
    await pumpApp(tester);

    expect(find.text("Nghĩa tiếng Việt"), findsOneWidget);
    expect(find.text("Thẻ mới"), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, "Kiểm tra"), findsOneWidget);
    expect(find.text("Sep1"), findsOneWidget);
  });

  testWidgets("nút bị vô hiệu hoá vẫn đọc được trên nền tối", (tester) async {
    await pumpApp(tester, isDark: true);

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, "Thẻ tiếp →"),
    );
    expect(button.onPressed, isNull, reason: "chưa trả lời thì phải bị khoá");

    // Màu chữ thực sự được vẽ ra. Trước khi cấp ThemeData cho MaterialApp,
    // chỗ này resolve thành đen mờ (onSurface 38% của light theme mặc định)
    // nên nút trông trống trơn trên nền thẻ tối.
    final style = tester
        .widget<DefaultTextStyle>(
          find
              .ancestor(
                of: find.text("Thẻ tiếp →"),
                matching: find.byType(DefaultTextStyle),
              )
              .first,
        )
        .style;

    final color = style.color!;
    expect(
      color.computeLuminance(),
      greaterThan(0.2),
      reason: "chữ phải sáng hơn nền thẻ tối, màu đang là $color",
    );
  });

  testWidgets("gõ sai thì hiện đáp án đúng và khoá 'Thẻ tiếp'", (tester) async {
    await pumpApp(tester);

    await tester.enterText(
      find.byType(TextField).first,
      "đáp án chắc chắn sai",
    );
    await tester.tap(find.widgetWithText(ElevatedButton, "Kiểm tra"));
    await tester.pump();

    expect(find.text("✕"), findsOneWidget);
    expect(find.text("Đã trả lời đúng?"), findsOneWidget);
    expect(find.text("Thẻ tiếp (chờ…)"), findsOneWidget);

    // Sau 2 giây khoá được gỡ.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text("Thẻ tiếp →"), findsOneWidget);
  });

  testWidgets("gõ đúng chỉ hiện '맞아', không nhắc lại đáp án", (tester) async {
    await pumpApp(tester);

    // Thứ tự thẻ có yếu tố ngẫu nhiên — tìm thẻ đang hiện rồi gõ đúng nó.
    const words = {"học sinh": "학생", "trường học": "학교", "quả táo": "사과"};
    final kr = words.entries
        .firstWhere((e) => find.text(e.key).evaluate().isNotEmpty)
        .value;
    await tester.enterText(find.byType(TextField).first, kr);
    await tester.tap(find.widgetWithText(ElevatedButton, "Kiểm tra"));
    await tester.pump();

    expect(find.textContaining("맞아"), findsOneWidget);
    expect(find.text("✕"), findsNothing);
    // Chỉ còn trong ô nhập (chữ vừa gõ), phần phản hồi không nhắc lại.
    expect(find.textContaining(kr), findsOneWidget);
  });

  testWidgets("bấm 'Đã trả lời đúng?' thì hiện '맞아' kèm đáp án", (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField).first, "sai chắc chắn");
    await tester.tap(find.widgetWithText(ElevatedButton, "Kiểm tra"));
    await tester.pump();
    await tapVisible(tester, find.text("Đã trả lời đúng?"));

    expect(find.text("✓"), findsOneWidget);
    expect(find.textContaining("맞아 — "), findsOneWidget);
    expect(find.text("Đã trả lời đúng?"), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets("'Xem đáp án' không cho tự xác nhận đúng", (tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, "Xem đáp án"));
    await tester.pump();

    expect(find.text("✕"), findsOneWidget);
    expect(find.text("Đã trả lời đúng?"), findsNothing);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets("'Đã thuộc' ghi nhận và chờ người học bấm sang thẻ mới", (
    tester,
  ) async {
    await pumpApp(tester);
    await tapKnown(tester);

    expect(find.textContaining("Đã đánh dấu thuộc"), findsOneWidget);
    expect(find.text("Thẻ tiếp →"), findsOneWidget);
  });

  testWidgets("không còn nhãn 'Còn N thẻ' trùng với ô thống kê", (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.textContaining("Còn "), findsNothing);
    expect(find.textContaining("Thuộc 0/2"), findsOneWidget);
  });

  group("⭐/漢 (mọi máy, kể cả offline)", () {
    testWidgets("hiện ngay trên thẻ, xếp hàng chờ gửi khi offline", (
      tester,
    ) async {
      final h = await pumpApp(tester);
      expect(find.text("★"), findsNothing);

      await openCardMenu(tester);
      await tester.tap(find.text("☆ Đánh dấu khó nhớ"));
      await tester.pumpAndSettle();

      expect(find.text("★"), findsOneWidget);
      expect(find.textContaining("1 mục chờ gửi"), findsOneWidget);
      final pending = await h.store.loadPendingFlags();
      expect(pending.single.marked, isTrue);
      // Bản cache nội dung cũng mang cờ mới -> mở lại app offline vẫn còn.
      final cached = await h.store.loadContent();
      expect(
        cached!.decks.expand((d) => d.cards).where((c) => c.marked),
        hasLength(1),
      );
    });

    testWidgets("có mạng thì gửi ngay, hàng đợi trống", (tester) async {
      final h = await pumpApp(tester, api: _FakeApi(online: true));
      await openCardMenu(tester);
      await tester.tap(find.text("漢 Đánh dấu Hán Hàn"));
      await tester.pumpAndSettle();

      expect(h.api.pushedFlags.single.hanja, isTrue);
      expect(h.api.pushedFlags.single.marked, isNull);
      expect(await h.store.loadPendingFlags(), isEmpty);
      expect(find.text("✓ Đã đồng bộ"), findsOneWidget);
    });
  });

  group("lịch sử học", () {
    testWidgets("học hết bộ -> ghi 1 lần học hoàn thành + gợi ý ôn lại", (
      tester,
    ) async {
      final h = await pumpApp(tester, api: _FakeApi(online: true));
      expect(find.text("chưa học"), findsOneWidget); // nhãn trong ô chọn bộ

      await finishDeck(tester);

      expect(find.textContaining("Bạn đã thuộc hết"), findsOneWidget);
      expect(find.textContaining("Lần sau: ôn lại ngày mai"), findsOneWidget);
      final s = h.api.pushedSessions.single;
      expect(s.deckId, "d1");
      expect(s.completed, isTrue);
      expect(s.masteredCount, 2);
      expect(s.totalCards, 2);
      expect(s.device, "android");
      expect(await h.store.loadDraft(), isNull);
    });

    testWidgets(
      "đổi bộ giữa chừng -> ghi 1 lần học dở; chưa trả lời thì không ghi",
      (tester) async {
        final h = await pumpApp(tester, api: _FakeApi(online: true));

        await tapVisible(tester, find.text("Sep2")); // chưa trả lời câu nào
        expect(h.api.pushedSessions, isEmpty);

        await tapKnown(tester); // bộ Sep2 (1 thẻ) — thuộc luôn = hoàn thành
        await tester.pump();
        await tapVisible(tester, find.text("Sep1"));
        await tester.enterText(find.byType(TextField).first, "sai");
        await tapVisible(
          tester,
          find.widgetWithText(ElevatedButton, "Kiểm tra"),
        );
        await tapVisible(tester, find.text("Sep2"));
        await tester.pump();

        expect(h.api.pushedSessions.map((s) => (s.deckId, s.completed)), [
          ("d2", true),
          ("d1", false),
        ]);
        expect(h.api.pushedSessions.last.attempted, 1);
        expect(h.api.pushedSessions.last.correct, 0);
      },
    );

    testWidgets("tắt app giữa chừng -> lần mở sau chốt thành lần học dở", (
      tester,
    ) async {
      final kv = MemoryStore();
      final draft = StudySessionRecord(
        id: "draft-0001",
        deckId: "d1",
        device: "ios",
        startedAt: _now.subtract(const Duration(hours: 1)),
        endedAt: _now.subtract(const Duration(minutes: 50)),
        attempted: 3,
        correct: 2,
        masteredCount: 1,
        totalCards: 2,
        completed: false,
      );
      await LocalStore(kv).saveDraft(draft);

      final h = await pumpApp(tester, kv: kv, api: _FakeApi(online: true));
      await tester.pump();

      final sent = h.api.pushedSessions.single;
      expect(sent.id, "draft-0001");
      expect(sent.completed, isFalse);
      // Kết thúc ở câu trả lời cuối, không phải lúc mở lại app.
      expect(sent.endedAt.isAtSameMomentAs(draft.endedAt), isTrue);
      expect(await h.store.loadDraft(), isNull);
      // Mở lại là lượt mới.
      expect(find.textContaining("Thuộc 0/2"), findsOneWidget);
    });

    testWidgets("offline: lần học nằm chờ, có mạng lại thì tự gửi", (
      tester,
    ) async {
      final h = await pumpApp(tester);
      await finishDeck(tester);

      expect(h.api.pushedSessions, isEmpty);
      expect(await h.store.loadPendingSessions(), hasLength(1));
      expect(
        find.textContaining("Ngoại tuyến · 1 mục chờ gửi"),
        findsOneWidget,
      );
      // Gợi ý ôn tính ngay trên máy, không cần chờ server.
      expect(find.textContaining("Lần sau: ôn lại ngày mai"), findsOneWidget);

      h.api.online = true;
      h.connectivity.reconnect();
      await tester.pump();
      await tester.pump();

      expect(h.api.pushedSessions, hasLength(1));
      expect(await h.store.loadPendingSessions(), isEmpty);
      expect(find.text("✓ Đã đồng bộ"), findsOneWidget);
    });

    testWidgets("lịch sử gộp lần học của máy khác, mở bảng xem được", (
      tester,
    ) async {
      final api = _FakeApi(online: true)
        ..remoteSessions.add(
          StudySessionRecord(
            id: "from-mac-001",
            deckId: "d1",
            device: "macOS",
            startedAt: DateTime(2026, 9, 20, 20),
            endedAt: DateTime(2026, 9, 20, 20, 15),
            attempted: 10,
            correct: 9,
            masteredCount: 2,
            totalCards: 2,
            completed: true,
          ),
        );
      await pumpApp(tester, api: api);
      await tester.pump();

      // Học tốt ngày 20 -> hẹn ngày 21 -> hôm nay 25 là quá hạn 4 ngày.
      expect(find.text("quá hạn 4 ngày"), findsOneWidget);
      await tester.tap(find.textContaining("Lịch sử"));
      await tester.pumpAndSettle();
      expect(find.textContaining("20/09 20:15 · Mac"), findsOneWidget);
      expect(
        find.textContaining("Học hết bộ · đúng 9/10 (90%)"),
        findsOneWidget,
      );
    });
  });

  group("nội dung", () {
    testWidgets("ưu tiên bản cache trên máy hơn bản đóng gói", (tester) async {
      final kv = MemoryStore();
      await LocalStore(kv).saveContent(
        contentOf([
          contentDeck("d1", const [
            {"kr": "나무", "vi": "cây"},
          ], name: "Bộ đã cache"),
        ]),
      );
      await pumpApp(tester, kv: kv);
      expect(find.text("Bộ đã cache"), findsOneWidget);
      expect(find.text("cây"), findsOneWidget);
    });

    testWidgets("có mạng thì tải nội dung mới về, lưu cache", (tester) async {
      final server = _content().updateCard(
        "d1-0",
        (c) => c.copyWith(vi: "học sinh (sửa trên Mac)"),
      );
      final h = await pumpApp(
        tester,
        api: _FakeApi(online: true, server: server),
      );
      await tester.pump();

      final cached = await h.store.loadContent();
      expect(jsonEncode(cached!.toJson()), jsonEncode(server.toJson()));
    });
  });

  group("soạn nội dung: chỉ Mac/web", () {
    testWidgets(
      "điện thoại: không có nút tạo/sửa",
      (tester) async {
        await pumpApp(tester);
        expect(find.text("+ Nhóm"), findsNothing);
        expect(find.text("+ Bộ mới"), findsNothing);
        await openCardMenu(tester);
        expect(find.text("✎ Sửa / xoá thẻ"), findsNothing);
        // ⭐/漢 vẫn dùng được trên điện thoại.
        expect(find.text("☆ Đánh dấu khó nhớ"), findsOneWidget);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );

    testWidgets("tạo bộ từ JSON dán vào -> gửi server, mở luôn bộ mới", (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final h = await pumpApp(tester, api: _FakeApi(online: true));

      await tester.tap(find.text("+ Bộ mới"));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(
        fields.at(1),
        '```json\n{"name": "Bài 12", "words": [{"kr": "나무", "vi": "cây"}, '
        '{"kr": "학교", "vi": "trường"}]}\n```',
      );
      await tester.pump();
      expect(find.text("✓ 2 từ (2 thẻ)"), findsOneWidget);
      expect(
        find.textContaining("Đã có sẵn trong các bộ khác"),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, "Tạo bộ"));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(h.api.server.decks.last.name, "Bài 12");
      expect(find.text("Bài 12"), findsOneWidget); // ô chọn bộ đã sang bộ mới
      expect(find.textContaining("Thuộc 0/2"), findsOneWidget);
    }, variant: desktop);

    testWidgets("offline: báo cần có mạng, không đóng hộp thoại", (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpApp(tester);

      await tester.tap(find.text("+ Nhóm"));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, "Sep4");
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, "Tạo"));
      await tester.pumpAndSettle();

      expect(find.textContaining("Cần có mạng"), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    }, variant: desktop);

    testWidgets("tạo nhóm rồi đổi tên nhóm", (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpApp(tester, api: _FakeApi(online: true));

      await tester.tap(find.text("+ Nhóm"));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, "Sep4");
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, "Tạo"));
      await tester.pumpAndSettle();

      expect(find.text("Sep4"), findsOneWidget);
      expect(find.text("Nhóm này chưa có bộ từ nào"), findsOneWidget);

      await tester.tap(find.text("✎"));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, "Sep 4 — Ôn thi");
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, "Lưu"));
      await tester.pumpAndSettle();

      expect(find.text("Sep 4 — Ôn thi"), findsOneWidget);
      expect(find.text("Sep4"), findsNothing);
    }, variant: desktop);

    testWidgets("sửa thẻ qua server, thẻ đang học đổi theo", (tester) async {
      final h = await pumpApp(tester, api: _FakeApi(online: true));
      final vi = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .firstWhere((d) => d == "học sinh" || d == "trường học")!;

      await openCardMenu(tester);
      await tester.tap(find.text("✎ Sửa / xoá thẻ"));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), "$vi (mới)");
      await tester.tap(find.widgetWithText(ElevatedButton, "Lưu"));
      await tester.pumpAndSettle();

      expect(find.text("$vi (mới)"), findsOneWidget);
      expect(
        h.api.server.decks.first.cards.where((c) => c.vi == "$vi (mới)"),
        hasLength(1),
      );
    }, variant: desktop);

    testWidgets("xoá hết thẻ của bộ thì báo bộ rỗng, không crash", (
      tester,
    ) async {
      final h = await pumpApp(tester, api: _FakeApi(online: true));
      for (var i = 0; i < 2; i++) {
        await tapVisible(tester, find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();
        await tester.tap(find.text("✎ Sửa / xoá thẻ"));
        await tester.pumpAndSettle();
        // Dialog cuộn được, nút xoá nằm dưới cùng -> cuộn tới rồi mới bấm.
        await tapVisible(tester, find.text("Xoá thẻ này"));
        await tester.pumpAndSettle();
        await tapVisible(tester, find.widgetWithText(TextButton, "Xoá"));
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
      expect(find.text("Bộ này chưa có thẻ nào"), findsOneWidget);
      expect(h.api.server.decks.first.cards, isEmpty);
    }, variant: desktop);

    testWidgets("ô gợi ý trong dialog sửa thẻ cao 3 dòng, giãn tới 5 dòng", (
      tester,
    ) async {
      await pumpApp(tester);
      await openCardMenu(tester);
      await tester.tap(find.text("✎ Sửa / xoá thẻ"));
      await tester.pumpAndSettle();

      // Thứ tự ô trong dialog: nghĩa Việt, từ Hàn, (đáp án phụ — thẻ giả không
      // có), gợi ý -> ô gợi ý là TextField cuối cùng trong dialog.
      final hintField = tester.widget<TextField>(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            )
            .last,
      );
      expect(hintField.minLines, 3);
      expect(hintField.maxLines, 5);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  testWidgets(
    "vị trí đầu nội dung không đổi giữa màn đang học và màn đã hoàn thành",
    (tester) async {
      // Mô phỏng cửa sổ desktop lớn (macOS) — bug chỉ lộ ra khi vùng trống
      // quanh nội dung đủ lớn để Center dồn khối nội dung xuống giữa.
      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpApp(tester);

      final headerFinder = find.textContaining("학습장", findRichText: true);
      final studyingTop = tester.getTopLeft(headerFinder).dy;

      // Học hết cả 2 thẻ trong bộ giả để chuyển sang màn "đã hoàn thành" —
      // nội dung ngắn hơn hẳn màn đang học (không còn ô nhập + 2 hàng nút).
      await finishDeck(tester);
      expect(find.textContaining("Bạn đã thuộc hết"), findsOneWidget);

      final completedTop = tester.getTopLeft(headerFinder).dy;

      expect(
        completedTop,
        studyingTop,
        reason:
            "Nội dung bị 'nhảy' vị trí giữa 2 màn hình — Center đang canh "
            "giữa theo chiều dọc dựa trên chiều cao nội dung thay vì ghim "
            "mép trên ổn định.",
      );
    },
  );

  testWidgets(
    "trạng thái đồng bộ và nút ••• nằm sát mép phải, nút học lại nằm giữa",
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpApp(tester, api: _FakeApi(online: true));
      await tester.pump();

      // Đo nút ••• lúc badge là "Thẻ mới" (ngắn) — đúng trường hợp lỗi thật
      // (Flexible + Spacer chia đôi phần trống). Đo cái NÚT, không đo icon:
      // icon 24px nằm giữa vùng bấm 48px nên luôn lùi vào 12px.
      final menuRight = tester
          .getTopRight(find.byType(PopupMenuButton<String>))
          .dx;
      final checkRight = tester
          .getTopRight(find.widgetWithText(ElevatedButton, "Kiểm tra"))
          .dx;
      expect(
        menuRight,
        closeTo(checkRight, 1),
        reason: "nút ••• (tuỳ chọn thẻ) chưa nằm sát mép phải của thẻ",
      );

      // Nút "Tối" và dòng trạng thái cùng nằm trong một Column canh phải
      // riêng (không kéo dãn chung cột với tiêu đề — kéo dãn chung sẽ làm
      // dòng trạng thái trôi cách rời tiêu đề, đã gặp thực tế).
      final toiButton = find.byType(OutlinedButton).first;
      final contentRightEdge = tester.getTopRight(toiButton).dx;
      final status = tester.getTopRight(find.text("✓ Đã đồng bộ"));
      expect(
        status.dx,
        closeTo(contentRightEdge, 1),
        reason: "dòng trạng thái đồng bộ chưa canh sát mép phải",
      );
      expect(
        status.dy - tester.getBottomLeft(toiButton).dy,
        lessThan(20),
        reason: "dòng trạng thái trôi cách xa nút Tối",
      );

      final restartCenter = tester
          .getCenter(find.text("Học lại bộ này từ đầu"))
          .dx;
      final screenCenter = tester.getSize(find.byType(MaterialApp)).width / 2;
      expect(
        restartCenter,
        closeTo(screenCenter, 2),
        reason: "nút 'Học lại bộ này từ đầu' chưa canh giữa",
      );
    },
  );

  group("điện thoại: bàn phím tiếng Hàn khi gõ", () {
    const channel = MethodChannel("flashcard/keyboard_language");
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    testWidgets(
      "iOS: focus ô trả lời -> xin bàn phím tiếng Hàn, rời ô -> trả lại",
      (tester) async {
        await pumpApp(tester);
        await tester.pump(); // ô trả lời tự focus sau frame đầu
        expect(
          calls.map((c) => (c.method, c.arguments)),
          contains(("prefer", "ko")),
        );

        // Trả lời xong -> ô bị vô hiệu hoá, mất focus -> bàn phím trả lại.
        await tapKnown(tester);
        expect(calls.last.method, "clear");
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      "Android: dùng hintLocales của chính TextField, không gọi native",
      (tester) async {
        await pumpApp(tester);
        await tester.pump();
        final field = tester.widget<TextField>(find.byType(TextField).first);
        expect(field.hintLocales, const [Locale("ko")]);
        expect(calls, isEmpty);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets("máy tính: không gọi native đổi bàn phím", (tester) async {
      await pumpApp(tester);
      await tester.pump();
      expect(calls, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group("điện thoại: tự cuộn khi focus ô trả lời", () {
    /// Màn hình điện thoại 390pt ngang; [visibleHeight] là phần còn thấy được
    /// phía trên bàn phím.
    void phoneScreen(WidgetTester tester, {required double visibleHeight}) {
      const height = 700.0;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, height);
      tester.view.viewInsets = FakeViewPadding(bottom: height - visibleHeight);
      addTearDown(tester.view.reset);
    }

    Future<void> focusAndSettle(WidgetTester tester) async {
      await pumpApp(tester);
      await tester.pump(); // tự focus ô trả lời
      await tester.pump(const Duration(milliseconds: 350)); // chờ debounce
      await tester.pump(const Duration(milliseconds: 300)); // animation cuộn
    }

    double pickerTop(WidgetTester tester) =>
        tester.getTopLeft(find.byType(DropdownButton<String>)).dy;
    double inputBottom(WidgetTester tester) => tester
        .getBottomLeft(find.widgetWithText(ElevatedButton, "Kiểm tra"))
        .dy;
    double pageOffset(WidgetTester tester) => tester
        .state<ScrollableState>(
          find
              .ancestor(
                of: find.byType(DropdownButton<String>),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;

    testWidgets(
      "cuộn tới khi ô chọn bộ từ sát mép trên, ô trả lời vẫn trên bàn phím",
      (tester) async {
        phoneScreen(tester, visibleHeight: 400);
        await focusAndSettle(tester);

        expect(pageOffset(tester), greaterThan(0));
        expect(pickerTop(tester), closeTo(8, 1));
        expect(inputBottom(tester), lessThanOrEqualTo(400));
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );

    testWidgets(
      "màn quá thấp không đủ chỗ cho cả hai -> ưu tiên thấy ô trả lời",
      (tester) async {
        phoneScreen(tester, visibleHeight: 250);
        await focusAndSettle(tester);

        expect(inputBottom(tester), lessThanOrEqualTo(250));
        expect(pickerTop(tester), lessThan(0));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets("máy tính: không tự cuộn", (tester) async {
      // Không có bàn phím ảo, ô trả lời vốn đã nằm trong vùng thấy được —
      // điện thoại sẽ cuộn (xem test trên), máy tính thì đứng yên.
      phoneScreen(tester, visibleHeight: 600);
      await focusAndSettle(tester);
      expect(pageOffset(tester), 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group("phím tắt", () {
    Future<void> pressWithCmd(
      WidgetTester tester,
      LogicalKeyboardKey key,
    ) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
    }

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }

    testWidgets("Cmd+Enter khi chưa trả lời = Đã thuộc", (tester) async {
      await pumpApp(tester);
      await pressWithCmd(tester, LogicalKeyboardKey.enter);
      expect(find.textContaining("Đã đánh dấu thuộc"), findsOneWidget);
    });

    testWidgets("Cmd+/ khi chưa trả lời = Xem đáp án", (tester) async {
      await pumpApp(tester);
      await pressWithCmd(tester, LogicalKeyboardKey.slash);
      expect(find.text("✕"), findsOneWidget);
      // Xem đáp án không được cho tự xác nhận đúng, giống nút bấm.
      expect(find.text("Đã trả lời đúng?"), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets("Enter thường khi chưa trả lời không bị coi là Đã thuộc", (
      tester,
    ) async {
      await pumpApp(tester);
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.textContaining("Đã đánh dấu thuộc"), findsNothing);
      expect(find.text("✕"), findsNothing);
    });

    testWidgets("Enter sau khi trả lời = Thẻ tiếp", (tester) async {
      await pumpApp(tester);
      await pressWithCmd(tester, LogicalKeyboardKey.enter);
      expect(find.textContaining("Đã đánh dấu thuộc"), findsOneWidget);

      await press(tester, LogicalKeyboardKey.enter);
      expect(find.textContaining("Đã đánh dấu thuộc"), findsNothing);
      expect(find.text("Thẻ mới"), findsOneWidget);
    });

    testWidgets("Cmd+Enter sau khi trả lời = Thẻ tiếp (không đánh dấu lại)", (
      tester,
    ) async {
      await pumpApp(tester);
      await pressWithCmd(tester, LogicalKeyboardKey.enter);
      // Phải thật sự đã trả lời trước, nếu không test pass "suông" khi cả hai
      // lần bấm đều không làm gì.
      expect(find.textContaining("Đã đánh dấu thuộc"), findsOneWidget);
      await pressWithCmd(tester, LogicalKeyboardKey.enter);
      expect(find.textContaining("Đã đánh dấu thuộc"), findsNothing);
      expect(find.text("Thẻ mới"), findsOneWidget);
    });

    testWidgets("Enter vẫn tôn trọng khoá 2 giây sau khi trả lời sai", (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.enterText(find.byType(TextField).first, "sai chắc chắn");
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text("✕"), findsOneWidget);

      await press(tester, LogicalKeyboardKey.enter); // đang khoá -> bỏ qua
      expect(find.text("✕"), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await press(tester, LogicalKeyboardKey.enter); // hết khoá -> sang thẻ
      expect(find.text("✕"), findsNothing);
    });

    testWidgets("không bắt phím khi dialog sửa thẻ đang mở", (tester) async {
      await pumpApp(tester);
      await openCardMenu(tester);
      await tester.tap(find.text("✎ Sửa / xoá thẻ"));
      await tester.pumpAndSettle();
      expect(find.text("Sửa thẻ"), findsOneWidget);

      await pressWithCmd(tester, LogicalKeyboardKey.enter);
      await tester.tap(find.text("Huỷ").last);
      await tester.pumpAndSettle();

      expect(find.textContaining("Đã đánh dấu thuộc"), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  testWidgets("đổi nhóm từ vựng không làm hỏng ô chọn bộ từ", (tester) async {
    await pumpApp(tester);
    expect(find.text("Bộ Sep1"), findsOneWidget);

    await tester.tap(find.text("Sep2"));
    await tester.pump();

    // Ô chọn phải theo kịp engine, không giữ lại deck của nhóm cũ.
    expect(tester.takeException(), isNull);
    expect(find.text("Bộ Sep2"), findsOneWidget);
    expect(find.text("Bộ Sep1"), findsNothing);
    expect(find.text("Nghĩa tiếng Việt"), findsOneWidget);
  });
}
