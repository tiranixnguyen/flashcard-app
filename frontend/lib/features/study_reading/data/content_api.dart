import "package:dio/dio.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/api/api_client.dart";
import "../models/content.dart";
import "../models/study_session_record.dart";

part "content_api.g.dart";

/// Lỗi gọi server. [offline] = không tới được server (không mạng, timeout,
/// server tắt) — tình huống bình thường với app offline-first; ngược lại là
/// server đã trả lời nhưng từ chối (400/404/500), [message] lấy từ body.
class ApiException implements Exception {
  const ApiException(this.message, {this.offline = false});

  final String message;
  final bool offline;

  @override
  String toString() => message;
}

/// Gọi backend. Trừu tượng hoá khỏi Dio để widget test dùng fake, xem
/// `DioContentApi` cho bản thật. Mọi lỗi đều ném [ApiException].
abstract class ContentApi {
  Future<ContentSnapshot> fetchContent();

  Future<ContentGroup> createGroup(String name);
  Future<ContentGroup> renameGroup(String groupId, String name);

  /// [words] đúng định dạng nhập bộ từ: `{front, back, hint?, note?,
  /// altAnswers?, typeAnswer?, followUp?/followUps?}` — server tự làm phẳng thẻ ngữ cảnh.
  Future<ContentDeck> createDeck({
    required String groupId,
    required String name,
    required List<Map<String, dynamic>> words,
  });
  Future<ContentDeck> appendCards(
    String deckId,
    List<Map<String, dynamic>> words,
  );

  Future<ContentCard> updateCard(
    String cardId, {
    required String front,
    required String back,
    required bool typeAnswer,
    String? hint,
    String? note,
    List<String> altAnswers = const [],
  });
  Future<void> deleteCard(String cardId);

  Future<void> pushFlagChanges(List<FlagChange> changes);
  Future<void> pushSessions(List<StudySessionRecord> sessions);
  Future<List<StudySessionRecord>> fetchSessions();
}

class DioContentApi implements ContentApi {
  DioContentApi(this._dio);
  final Dio _dio;

  /// Gọi [path] rồi [parse] body — cả hai nằm trong cùng một khối bắt lỗi, nên
  /// body sai định dạng (server khác phiên bản, proxy/captive portal trả HTML)
  /// cũng thành [ApiException] thay vì lọt `TypeError` ra ngoài và làm đồng
  /// bộ kẹt ở trạng thái "đang đồng bộ".
  Future<T> _request<T>(
    String method,
    String path, {
    Object? body,
    required T Function(Map<String, dynamic> json) parse,
  }) async {
    try {
      final res = await _dio.request<Object?>(
        path,
        data: body,
        options: Options(method: method),
      );
      final data = res.data;
      return parse(data is Map<String, dynamic> ? data : const {});
    } on DioException catch (e) {
      final res = e.response;
      if (res == null) {
        throw const ApiException("Không kết nối được server.", offline: true);
      }
      final data = res.data;
      final msg = data is Map && data["error"] is String
          ? data["error"] as String
          : "Server lỗi (${res.statusCode}).";
      throw ApiException(msg);
    } on Object {
      throw const ApiException("Server trả về dữ liệu không đọc được.");
    }
  }

  static void _ignore(Map<String, dynamic> _) {}

  @override
  Future<ContentSnapshot> fetchContent() =>
      _request("GET", "/content", parse: ContentSnapshot.fromJson);

  @override
  Future<ContentGroup> createGroup(String name) => _request(
    "POST",
    "/groups",
    body: {"name": name},
    parse: ContentGroup.fromJson,
  );

  @override
  Future<ContentGroup> renameGroup(String groupId, String name) => _request(
    "PATCH",
    "/groups/$groupId",
    body: {"name": name},
    parse: ContentGroup.fromJson,
  );

  @override
  Future<ContentDeck> createDeck({
    required String groupId,
    required String name,
    required List<Map<String, dynamic>> words,
  }) => _request(
    "POST",
    "/decks",
    body: {"groupId": groupId, "name": name, "words": words},
    parse: ContentDeck.fromJson,
  );

  @override
  Future<ContentDeck> appendCards(
    String deckId,
    List<Map<String, dynamic>> words,
  ) => _request(
    "POST",
    "/decks/$deckId/cards",
    body: {"words": words},
    parse: ContentDeck.fromJson,
  );

  @override
  Future<ContentCard> updateCard(
    String cardId, {
    required String front,
    required String back,
    required bool typeAnswer,
    String? hint,
    String? note,
    List<String> altAnswers = const [],
  }) => _request(
    "PATCH",
    "/cards/$cardId",
    body: {
      "front": front,
      "back": back,
      "typeAnswer": typeAnswer,
      "hint": hint,
      // Luôn gửi (kể cả null = xoá): server hiểu thiếu trường là "giữ nguyên".
      "note": note,
      "altAnswers": altAnswers,
    },
    parse: ContentCard.fromJson,
  );

  @override
  Future<void> deleteCard(String cardId) =>
      _request("DELETE", "/cards/$cardId", parse: _ignore);

  @override
  Future<void> pushFlagChanges(List<FlagChange> changes) => _request(
    "POST",
    "/cards/flags",
    body: {
      "changes": [for (final c in changes) c.toJson()],
    },
    parse: _ignore,
  );

  @override
  Future<void> pushSessions(List<StudySessionRecord> sessions) => _request(
    "POST",
    "/sessions",
    body: {
      "sessions": [for (final s in sessions) s.toJson()],
    },
    parse: _ignore,
  );

  @override
  Future<List<StudySessionRecord>> fetchSessions() => _request(
    "GET",
    "/sessions",
    parse: (json) => [
      for (final s in json["sessions"] as List)
        StudySessionRecord.fromJson(s as Map<String, dynamic>),
    ],
  );
}

@riverpod
ContentApi contentApi(Ref ref) => DioContentApi(ref.watch(dioProvider));
