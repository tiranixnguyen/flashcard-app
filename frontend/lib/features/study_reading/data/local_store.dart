import "dart:convert";

import "package:riverpod_annotation/riverpod_annotation.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../models/content.dart";
import "../models/study_session_record.dart";

part "local_store.g.dart";

/// Kho khoá–chuỗi tối giản. Tách ra để widget test dùng bản trong bộ nhớ —
/// SharedPreferences thật đi qua platform channel, trong `testWidgets` sẽ treo.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class SharedPrefsStore implements KeyValueStore {
  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);

  @override
  Future<void> remove(String key) async =>
      (await SharedPreferences.getInstance()).remove(key);
}

class MemoryStore implements KeyValueStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> remove(String key) async => data.remove(key);
}

/// Mọi thứ app lưu trên máy:
/// - bản cache nội dung (để mở app offline),
/// - lịch sử các lần học đã biết (của mọi máy, tải từ server),
/// - hàng đợi chờ gửi: lần học mới + lần bật/tắt ⭐/漢,
/// - lần học đang dở (để tắt app giữa chừng vẫn ghi được "học dở").
///
/// Dữ liệu hỏng thì coi như không có — mở được app quan trọng hơn.
class LocalStore {
  LocalStore(this._kv);
  final KeyValueStore _kv;

  static const contentKey = "vocab-content-v2";
  static const sessionsKey = "vocab-sessions";
  static const pendingSessionsKey = "vocab-outbox-sessions";
  static const pendingFlagsKey = "vocab-outbox-flags";
  static const draftKey = "vocab-session-draft";

  // Bản cũ lưu tiến trình từng thẻ ở "vocab-app-state" — không đọc nữa nhưng
  // cố ý không xoá, phòng khi cần cứu thay đổi chưa kịp đồng bộ.

  Future<Object?> _readJson(String key) async {
    final raw = await _kv.read(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> _writeJson(String key, Object value) =>
      _kv.write(key, jsonEncode(value));

  Future<List<T>> _readList<T>(
    String key,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final json = await _readJson(key);
    if (json is! List) return [];
    try {
      return [for (final e in json) parse(e as Map<String, dynamic>)];
    } on Object {
      return [];
    }
  }

  // --------------------------------------------------------------- nội dung

  Future<ContentSnapshot?> loadContent() async {
    final json = await _readJson(contentKey);
    if (json is! Map<String, dynamic>) return null;
    try {
      return ContentSnapshot.fromJson(json);
    } on Object {
      return null;
    }
  }

  Future<void> saveContent(ContentSnapshot content) =>
      _writeJson(contentKey, content.toJson());

  // ------------------------------------------------------------ lịch sử học

  Future<List<StudySessionRecord>> loadSessions() =>
      _readList(sessionsKey, StudySessionRecord.fromJson);

  Future<void> saveSessions(List<StudySessionRecord> sessions) =>
      _writeJson(sessionsKey, [for (final s in sessions) s.toJson()]);

  Future<List<StudySessionRecord>> loadPendingSessions() =>
      _readList(pendingSessionsKey, StudySessionRecord.fromJson);

  Future<void> savePendingSessions(List<StudySessionRecord> sessions) =>
      _writeJson(pendingSessionsKey, [for (final s in sessions) s.toJson()]);

  Future<List<FlagChange>> loadPendingFlags() =>
      _readList(pendingFlagsKey, FlagChange.fromJson);

  Future<void> savePendingFlags(List<FlagChange> changes) =>
      _writeJson(pendingFlagsKey, [for (final c in changes) c.toJson()]);

  // ------------------------------------------------------- lần học đang dở

  Future<StudySessionRecord?> loadDraft() async {
    final json = await _readJson(draftKey);
    if (json is! Map<String, dynamic>) return null;
    try {
      return StudySessionRecord.fromJson(json);
    } on Object {
      return null;
    }
  }

  Future<void> saveDraft(StudySessionRecord draft) =>
      _writeJson(draftKey, draft.toJson());

  Future<void> clearDraft() => _kv.remove(draftKey);
}

@riverpod
LocalStore localStore(Ref ref) => LocalStore(SharedPrefsStore());
