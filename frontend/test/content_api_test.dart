import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:flashcard_app/features/study_reading/data/content_api.dart";
import "package:flashcard_app/features/study_reading/models/content.dart";
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
  test("GET /content parse đủ nhóm, bộ, thẻ ngữ cảnh", () async {
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
            "cards": [
              {
                "id": "ds1-0",
                "position": 0,
                "parentId": null,
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
                "parentId": "ds1-0",
                "back": "가다",
                "front": "đi học",
                "hint": "ngữ cảnh",
                "altAnswers": ["갑니다"],
                "typeAnswer": false,
                "marked": false,
                "hanja": true,
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
    expect(cards[1].parentId, "ds1-0");
    expect(cards[1].altAnswers, ["갑니다"]);
    expect(cards[1].hanja, isTrue);
    expect([cards[0].typeAnswer, cards[1].typeAnswer], [true, false]);
  });

  test("cache cũ kr/vi (trước khi có thẻ tự chấm) vẫn đọc được", () {
    final c = ContentCard.fromJson({
      "id": "ds1-0",
      "position": 0,
      "parentId": null,
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

  test("PATCH /cards/:id gửi front/back/typeAnswer/note", () async {
    final (api, adapter) = _api(
      (_) => _json(200, {
        "id": "c1",
        "position": 0,
        "parentId": null,
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
