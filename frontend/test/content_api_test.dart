import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:flashcard_app/features/study_reading/data/content_api.dart";
import "package:flashcard_app/features/study_reading/models/card_audio.dart";
import "package:flashcard_app/features/study_reading/models/content.dart";
import "package:flashcard_app/features/study_reading/models/deck.dart";
import "package:flashcard_app/features/study_reading/models/study_session_record.dart";
import "package:flutter_test/flutter_test.dart";

/// Giả ở tầng HTTP (không mock `ContentApi`) để test đúng phần parse JSON và
/// phân loại lỗi của `DioContentApi`.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  /// Trả `null` = mô phỏng không tới được server.
  final ResponseBody? Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final res = respond(options);
    if (res == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: "offline",
      );
    }
    return res;
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object? body) => ResponseBody.fromString(
  body == null ? "" : jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

(DioContentApi, _FakeAdapter) _api(ResponseBody? Function(RequestOptions) r) {
  final adapter = _FakeAdapter(r);
  final dio = Dio(BaseOptions(baseUrl: "http://test"))
    ..httpClientAdapter = adapter;
  return (DioContentApi(dio), adapter);
}

void main() {
  test("GET /content parse đủ nhóm, bộ, thẻ", () async {
    final (api, _) = _api(
      (_) => _json(200, {
        "groups": [
          {"id": "g1", "name": "Sep1", "position": 0},
        ],
        "decks": [
          {
            "id": "ds1",
            "groupId": "g1",
            "name": "Bộ 1",
            "position": 0,
            "type": "listening",
            "description": "Nghe https://a.com",
            "cards": [
              {
                "id": "ds1-0",
                "position": 0,
                "back": "가다",
                "front": "đi",
                "hint": null,
                "altAnswers": [],
                "typeAnswer": true,
                "marked": true,
                "hanja": false,
              },
              {
                "id": "ds1-1",
                "position": 1,
                "back": "가다",
                "front": "đi học",
                "hint": "gợi ý",
                "altAnswers": ["갑니다"],
                "typeAnswer": false,
                "marked": false,
                "hanja": true,
                "passage": true,
              },
            ],
          },
        ],
      }),
    );
    final c = await api.fetchContent();
    expect(c.groups.single.name, "Sep1");
    final cards = c.decks.single.cards;
    expect(cards[0].marked, isTrue);
    expect(cards[1].altAnswers, ["갑니다"]);
    expect(cards[1].hanja, isTrue);
    // Cache/server cũ chưa có `passage` -> false.
    expect([cards[0].passage, cards[1].passage], [false, true]);
    expect([cards[0].typeAnswer, cards[1].typeAnswer], [true, false]);
    expect(c.decks.single.type, DeckType.listening);
    expect(c.decks.single.toJson()["type"], "listening");
    expect(c.decks.single.description, "Nghe https://a.com");
    expect(
      c.decks.single.copyWith(cards: []).description,
      "Nghe https://a.com",
    );
  });

  test("loại bộ: thiếu (cache cũ) hoặc giá trị lạ -> chưa phân loại", () {
    ContentDeck deck(Object? type) => ContentDeck.fromJson({
      "id": "ds1",
      "groupId": "g1",
      "name": "Bộ 1",
      "position": 0,
      "type": ?type,
      "cards": [],
    });
    expect(deck(null).type, isNull);
    expect(deck(null).description, isNull); // cache cũ chưa có mô tả
    expect(deck("music").type, isNull);
    expect(deck("grammar").type, DeckType.grammar);
    expect(deck("grammar").copyWith(cards: []).type, DeckType.grammar);
  });

  test("tạo bộ gửi kèm loại; đổi loại = PATCH /decks/:id", () async {
    final deckJson = {
      "id": "dx",
      "groupId": "g1",
      "name": "Nghe",
      "position": 0,
      "type": "reading",
      "cards": [],
    };
    final (api, adapter) = _api((_) => _json(200, deckJson));
    await api.createDeck(
      groupId: "g1",
      name: "Nghe",
      words: const [],
      type: DeckType.speaking,
      description: "mô tả",
    );
    expect(adapter.requests.last.data, containsPair("type", "speaking"));
    expect(adapter.requests.last.data, containsPair("description", "mô tả"));

    final d = await api.updateDeckInfo(
      "dx",
      name: "Nghe 2",
      type: null,
      description: null,
    );
    final req = adapter.requests.last;
    expect(
      [req.method, req.path, req.data],
      [
        "PATCH",
        "/decks/dx",
        {"name": "Nghe 2", "type": null, "description": null},
      ],
    );
    expect(d.type, DeckType.reading);
  });

  test("cache cũ kr/vi (trước khi có thẻ tự chấm) vẫn đọc được", () {
    final c = ContentCard.fromJson({
      "id": "ds1-0",
      "position": 0,
      "kr": "가다",
      "vi": "đi",
      "hint": null,
      "altAnswers": [],
      "marked": false,
      "hanja": false,
    });
    expect([c.front, c.back], ["đi", "가다"]);
    expect(c.typeAnswer, isTrue); // thẻ cũ đều là thẻ gõ đáp án
    expect(c.toJson().keys, containsAll(["front", "back", "typeAnswer"]));
    expect(c.toJson().keys, isNot(contains("kr")));
  });

  test(
    "cache cũ còn thẻ ngữ cảnh: parentId bị bỏ, thẻ con thành thẻ thường",
    () {
      final c = ContentCard.fromJson({
        "id": "ds2-9",
        "position": 9,
        "parentId": "ds2-8",
        "front": "con của chúng tôi",
        "back": "우리 아이",
        "typeAnswer": true,
      });
      expect(c.back, "우리 아이");
      expect(c.toJson().keys, isNot(contains("parentId")));
    },
  );

  test("PATCH /cards/:id gửi front/back/typeAnswer/note", () async {
    final (api, adapter) = _api(
      (_) => _json(200, {
        "id": "c1",
        "position": 0,
        "front": "đi",
        "back": "가다",
        "hint": null,
        "altAnswers": [],
        "typeAnswer": false,
        "marked": false,
        "hanja": false,
      }),
    );
    final card = await api.updateCard(
      "c1",
      front: "đi",
      back: "가다",
      typeAnswer: false,
    );
    expect(card.typeAnswer, isFalse);
    expect(adapter.requests.single.method, "PATCH");
    expect(adapter.requests.single.data, {
      "front": "đi",
      "back": "가다",
      "typeAnswer": false,
      "hint": null,
      "note": null,
      "altAnswers": <String>[],
    });
  });

  group("file nghe", () {
    Map<String, Object?> cardJson(Map<String, Object?> extra) => {
      "id": "c1",
      "position": 0,
      "front": "đi",
      "back": "가다",
      "typeAnswer": true,
      ...extra,
    };

    test(
      "thẻ đọc/ghi id file nghe từng trường; cache cũ không có thì rỗng",
      () {
        final c = ContentCard.fromJson(
          cardJson({
            "backAudioId": "a1",
            "noteAudioId": "a2",
            "hintAudioId": "",
          }),
        );
        expect(c.audio[CardField.back], "a1");
        expect(c.audio[CardField.note], "a2");
        expect(c.audio[CardField.hint], isNull); // chuỗi rỗng coi như không có
        expect(ContentCard.fromJson(c.toJson()).audio, c.audio);
        expect(ContentCard.fromJson(cardJson({})).audio.isEmpty, isTrue);
      },
    );

    test("withField gắn/gỡ đúng một trường", () {
      final a = CardAudio.none
          .withField(CardField.front, "f")
          .withField(CardField.back, "b");
      final removed = a.withField(CardField.front, null);
      expect(removed[CardField.front], isNull);
      expect(removed[CardField.back], "b");
      expect(a[CardField.front], "f"); // bản gốc không đổi
    });

    test("POST /audio gửi bytes MP3 thô, trả về id", () async {
      final (api, adapter) = _api((_) => _json(201, {"id": "a9", "size": 4}));
      final bytes = Uint8List.fromList([0x49, 0x44, 0x33, 0x04]);
      expect(await api.uploadAudio(bytes), "a9");
      final req = adapter.requests.single;
      expect([req.method, req.path], ["POST", "/audio"]);
      expect(req.contentType, "audio/mpeg");
      expect(req.data, bytes);
    });

    test("server từ chối file -> ApiException kèm thông báo", () async {
      final (api, _) = _api((_) => _json(415, {"error": "Chỉ nhận file MP3."}));
      await expectLater(
        api.uploadAudio(Uint8List(4)),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            "message",
            "Chỉ nhận file MP3.",
          ),
        ),
      );
    });

    test(
      "PATCH /cards/:id: có audio thì gửi đủ 4 trường (null = gỡ)",
      () async {
        final (api, adapter) = _api(
          (_) => _json(200, cardJson({"backAudioId": "b"})),
        );
        await api.updateCard(
          "c1",
          front: "đi",
          back: "가다",
          typeAnswer: true,
          audio: CardAudio.none.withField(CardField.back, "b"),
        );
        expect(adapter.requests.single.data, containsPair("backAudioId", "b"));
        expect(
          adapter.requests.single.data,
          containsPair("frontAudioId", null),
        );
        expect(adapter.requests.single.data, containsPair("noteAudioId", null));
      },
    );

    test("địa chỉ phát theo baseUrl", () {
      final (api, _) = _api((_) => null);
      expect(api.audioUrl("a 1"), "http://test/audio/a%201");
    });
  });

  test("không tới được server -> ApiException(offline)", () async {
    final (api, _) = _api((_) => null);
    await expectLater(
      api.fetchContent(),
      throwsA(isA<ApiException>().having((e) => e.offline, "offline", isTrue)),
    );
  });

  test(
    "server từ chối -> lấy thông báo lỗi từ body, không phải offline",
    () async {
      final (api, _) = _api(
        (_) => _json(400, {"error": "Tên nhóm không được trống."}),
      );
      await expectLater(
        api.createGroup(" "),
        throwsA(
          isA<ApiException>()
              .having((e) => e.offline, "offline", isFalse)
              .having(
                (e) => e.message,
                "message",
                "Tên nhóm không được trống.",
              ),
        ),
      );
    },
  );

  test("500 không có body -> thông báo chung kèm mã", () async {
    final (api, _) = _api((_) => _json(500, null));
    await expectLater(
      api.fetchSessions(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          "message",
          contains("500"),
        ),
      ),
    );
  });

  group(
    "body 200 nhưng sai định dạng -> ApiException, không lọt TypeError",
    () {
      final notOffline = throwsA(
        isA<ApiException>().having((e) => e.offline, "offline", isFalse),
      );

      test("trang HTML (proxy, captive portal)", () async {
        final (api, _) = _api(
          (_) => ResponseBody.fromString(
            "<html>Đăng nhập Wi-Fi</html>",
            200,
            headers: {
              Headers.contentTypeHeader: ["text/html"],
            },
          ),
        );
        await expectLater(api.fetchContent(), notOffline);
        await expectLater(api.fetchSessions(), notOffline);
      });

      test("JSON thiếu trường / sai kiểu", () async {
        final (api, _) = _api(
          (_) => _json(200, {
            "groups": "không phải mảng",
            "sessions": [
              {"id": 1},
            ],
          }),
        );
        await expectLater(api.fetchContent(), notOffline);
        await expectLater(api.fetchSessions(), notOffline);
      });
    },
  );

  test("POST /sessions gửi đúng body, thời gian dạng UTC ISO", () async {
    final (api, adapter) = _api(
      (_) => _json(200, {"received": 1, "inserted": 1, "unknownDeck": 0}),
    );
    await api.pushSessions([
      StudySessionRecord(
        id: "abcdef0123456789",
        deckId: "ds1",
        device: "ios",
        startedAt: DateTime.utc(2026, 9, 25, 1),
        endedAt: DateTime.utc(2026, 9, 25, 1, 20),
        attempted: 12,
        correct: 10,
        masteredCount: 8,
        totalCards: 8,
        completed: true,
      ),
    ]);
    final req = adapter.requests.single;
    expect(req.method, "POST");
    expect(req.path, "/sessions");
    final body = req.data as Map<String, dynamic>;
    final s = (body["sessions"] as List).single as Map<String, dynamic>;
    expect(s["endedAt"], "2026-09-25T01:20:00.000Z");
    expect(s["completed"], isTrue);
  });

  test("POST /cards/flags chỉ gửi cờ có đổi", () async {
    final (api, adapter) = _api(
      (_) => _json(200, {"applied": 1, "ignored": 0}),
    );
    await api.pushFlagChanges([
      FlagChange(
        cardId: "ds1-0",
        changedAt: DateTime.utc(2026, 9, 25),
        marked: true,
      ),
    ]);
    final change =
        ((adapter.requests.single.data as Map)["changes"] as List).single
            as Map;
    expect(change, {
      "cardId": "ds1-0",
      "changedAt": "2026-09-25T00:00:00.000Z",
      "marked": true,
    });
  });

  test("DELETE /cards/:id nhận 204 không body", () async {
    final (api, adapter) = _api((_) => _json(204, null));
    await api.deleteCard("ds1-3");
    expect(adapter.requests.single.method, "DELETE");
    expect(adapter.requests.single.path, "/cards/ds1-3");
  });
}
