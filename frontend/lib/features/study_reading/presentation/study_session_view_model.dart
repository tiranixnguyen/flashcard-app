import "dart:async";
import "dart:convert";

import "package:flutter/services.dart" show HapticFeedback;
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/clock/clock.dart";
import "../../../core/platform/platform.dart";
import "../data/bundled_content.dart";
import "../data/connectivity_gateway.dart";
import "../data/content_api.dart";
import "../data/local_store.dart";
import "../domain/review_schedule.dart";
import "../domain/study_engine.dart";
import "../models/content.dart";
import "../models/deck.dart";
import "../models/study_session_record.dart";
import "../models/study_word.dart";

part "study_session_view_model.g.dart";

/// Trạng thái đồng bộ với server, hiển thị ở góc header. Đồng bộ là việc chạy
/// nền: học offline vẫn bình thường, lần học và ⭐/漢 nằm chờ trong hàng đợi.
enum SyncStatus { idle, syncing, synced, offline, error }

/// Ảnh chụp bất biến của [StudyEngine] + lịch sử học để UI vẽ lại.
class StudySessionState {
  const StudySessionState({
    required this.deckOptions,
    required this.hasVisibleDecks,
    required this.vocabGroups,
    required this.currentGroupId,
    required this.currentDeckId,
    required this.currentDeckName,
    required this.isVirtualDeck,
    required this.word,
    required this.cardSerial,
    required this.outcome,
    required this.canOverride,
    required this.overridden,
    required this.isNewCard,
    required this.streak,
    required this.isMarked,
    required this.isHanja,
    required this.correctCount,
    required this.attemptedCount,
    required this.masteredCount,
    required this.totalCount,
    required this.nextLocked,
    required this.syncStatus,
    required this.pendingCount,
    required this.review,
    required this.history,
    required this.knownKorean,
  });

  final List<DeckOption> deckOptions;

  /// `false` khi nhóm từ vựng đang chọn chưa có bộ từ nào. Không suy ra được từ
  /// [deckOptions] vì danh sách đó luôn kèm ba deck ảo.
  final bool hasVisibleDecks;

  final List<VocabGroup> vocabGroups;
  final String currentGroupId;
  final String? currentDeckId;
  final String? currentDeckName;

  /// Bộ ảo (⭐/漢/🔀): không ghi lịch sử, không gợi ý ôn, không thêm từ được.
  final bool isVirtualDeck;

  /// `null` khi đã thuộc hết deck hoặc nhóm không có deck nào.
  final StudyWord? word;

  /// Đổi mỗi khi hỏi sang lượt/thẻ mới — xem [StudyEngine.cardSerial].
  final int cardSerial;

  final AnswerOutcome outcome;
  final bool canOverride;

  /// Xem [StudyEngine.overridden].
  final bool overridden;
  final bool isNewCard;
  final int streak;
  final bool isMarked;
  final bool isHanja;

  final int correctCount;
  final int attemptedCount;
  final int masteredCount;
  final int totalCount;

  /// Sau khi trả lời sai, "Thẻ tiếp" bị khoá 2 giây để ép nhìn kỹ đáp án.
  final bool nextLocked;

  final SyncStatus syncStatus;

  /// Số mục (lần học + ⭐/漢) đang chờ gửi lên server.
  final int pendingCount;

  /// Gợi ý ôn lại bộ đang mở (`null` với bộ ảo).
  final ReviewStatus? review;

  /// Các lần học bộ đang mở, mới nhất trước (mọi máy).
  final List<StudySessionRecord> history;

  /// Mọi từ tiếng Hàn đang có — trình tạo bộ dùng để báo từ trùng.
  final Set<String> knownKorean;

  bool get answered => outcome != AnswerOutcome.pending;
  bool get isCompleted => word == null && totalCount > 0;
  bool get isEmptyGroup => !hasVisibleDecks;

  /// Bộ đang mở không có thẻ nào: xoá hết thẻ, hoặc bỏ cờ thẻ cuối cùng
  /// trong deck ⭐/漢.
  bool get isEmptyDeck => word == null && totalCount == 0;
  double get progress => totalCount == 0 ? 0 : masteredCount / totalCount;
  int get masteryStreak => StudyEngine.masteryStreak;
}

/// Một mục trong danh sách chọn deck (gồm cả các deck ảo).
class DeckOption {
  const DeckOption({
    required this.id,
    required this.label,
    this.review,
    this.enabled = true,
  });

  final String id;
  final String label;

  /// Gợi ý ôn lại (chỉ bộ thật) — hiện mờ sau tên bộ.
  final ReviewStatus? review;
  final bool enabled;
}

@riverpod
class StudySessionViewModel extends _$StudySessionViewModel {
  StudyEngine? _engine;
  late ContentSnapshot _content;
  List<StudySessionRecord> _sessions = [];
  List<StudySessionRecord> _pendingSessions = [];
  List<FlagChange> _pendingFlags = [];

  /// Lần học đang diễn ra — bắt đầu ở câu trả lời đầu tiên trong một bộ thật.
  StudySessionRecord? _draft;

  Timer? _nextLockTimer;
  StreamSubscription<void>? _reconnectSub;
  bool _nextLocked = false;
  SyncStatus _syncStatus = SyncStatus.idle;

  /// Guard chống đồng bộ chồng lấn: có yêu cầu mới trong lúc đang chạy thì
  /// nhớ lại để chạy thêm một vòng ngay sau, không bỏ mất.
  bool _syncing = false;
  bool _syncAgain = false;

  LocalStore get _store => ref.read(localStoreProvider);
  ContentApi get _api => ref.read(contentApiProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  Future<StudySessionState> build() async {
    final store = ref.watch(localStoreProvider);

    // Nội dung: bản cache (lần tải server gần nhất) → không có thì bản đóng
    // gói trong app. Server được hỏi ở nền, không bắt người học chờ mạng.
    _content =
        await store.loadContent() ??
        await ref.watch(bundledContentProvider).load();
    _sessions = await store.loadSessions();
    _pendingSessions = await store.loadPendingSessions();
    _pendingFlags = await store.loadPendingFlags();

    // Lần trước tắt app giữa chừng -> ghi thành một lần học dở, kết thúc ở
    // câu trả lời cuối cùng. Mở lại là lần mới.
    final leftover = await store.loadDraft();
    if (leftover != null) await _finish(leftover, completed: false);

    final catalog = buildStudyCatalog(_content);
    _engine = StudyEngine(
      decks: catalog.decks,
      vocabGroups: catalog.vocabGroups,
      markedIds: catalog.markedIds,
      hanjaIds: catalog.hanjaIds,
    )..bootstrap();

    _reconnectSub = ref
        .watch(connectivityGatewayProvider)
        .onReconnected
        .listen((_) => unawaited(syncNow()));
    ref.onDispose(() {
      _nextLockTimer?.cancel();
      _reconnectSub?.cancel();
    });

    unawaited(syncNow());
    return _snapshot();
  }

  // ------------------------------------------------------------- snapshot

  StudySessionState _snapshot() {
    final e = _engine!;
    final progress = e.currentProgress;
    final deck = e.currentDeck;
    final now = _now();
    final byDeck = <String, List<StudySessionRecord>>{};
    for (final s in _sessions) {
      (byDeck[s.deckId] ??= []).add(s);
    }
    ReviewStatus reviewOf(String id) =>
        computeReviewStatus(byDeck[id] ?? const [], now);

    final isVirtual = deck?.isVirtual ?? false;
    return StudySessionState(
      deckOptions: _deckOptions(e, reviewOf),
      hasVisibleDecks: e.visibleDecks.isNotEmpty,
      vocabGroups: e.vocabGroups,
      currentGroupId: e.currentVocabGroup,
      currentDeckId: e.currentDeckId,
      currentDeckName: deck?.name,
      isVirtualDeck: isVirtual,
      word: e.currentWord,
      cardSerial: e.cardSerial,
      outcome: e.outcome,
      canOverride: e.canOverride,
      overridden: e.overridden,
      isNewCard:
          progress == null || (progress.box == 0 && progress.streak == 0),
      streak: progress?.streak ?? 0,
      isMarked: e.currentIsMarked,
      isHanja: e.currentIsHanja,
      correctCount: e.correctCount,
      attemptedCount: e.attemptedCount,
      masteredCount: e.masteredCount,
      totalCount: e.totalCount,
      nextLocked: _nextLocked,
      syncStatus: _syncStatus,
      pendingCount: _pendingSessions.length + _pendingFlags.length,
      review: deck == null || isVirtual ? null : reviewOf(deck.id),
      history: deck == null || isVirtual
          ? const []
          : ([...?byDeck[deck.id]]
              ..sort((a, b) => b.endedAt.compareTo(a.endedAt))),
      knownKorean: _content.allKorean,
    );
  }

  List<DeckOption> _deckOptions(
    StudyEngine e,
    ReviewStatus Function(String) reviewOf,
  ) {
    final marked = e.markedCount;
    final hanja = e.hanjaCount;
    return [
      for (final d in e.visibleDecks)
        DeckOption(id: d.id, label: d.name, review: reviewOf(d.id)),
      DeckOption(
        id: markedDeckId,
        label: "⭐ Từ khó nhớ ($marked)",
        enabled: marked > 0,
      ),
      DeckOption(
        id: hanjaDeckId,
        label: "漢 Từ Hán Hàn ($hanja)",
        enabled: hanja > 0,
      ),
      const DeckOption(id: randomDeckId, label: "🔀 Deck ngẫu nhiên"),
    ];
  }

  void _emit() {
    if (_engine != null) state = AsyncData(_snapshot());
  }

  // ------------------------------------------------------------- lần học

  /// Gọi sau mỗi câu trả lời: mở lần học nếu chưa có, cập nhật số liệu, lưu
  /// nháp (tắt app giữa chừng vẫn còn), và chốt lại khi đã thuộc hết bộ.
  Future<void> _recordAnswer() async {
    final e = _engine!;
    final deck = e.currentDeck;
    if (deck == null || deck.isVirtual) return; // bộ ảo không ghi lịch sử
    final now = _now();
    final draft =
        (_draft ??= StudySessionRecord(
          id: newSessionId(),
          deckId: deck.id,
          device: deviceName,
          startedAt: now,
          endedAt: now,
          attempted: 0,
          correct: 0,
          masteredCount: 0,
          totalCards: 0,
          completed: false,
        )).copyWith(
          endedAt: now,
          attempted: e.attemptedCount,
          correct: e.correctCount,
          masteredCount: e.masteredCount,
          totalCards: e.totalCount,
        );
    _draft = draft;
    if (e.totalCount > 0 && e.masteredCount >= e.totalCount) {
      _draft = null;
      await _finish(draft, completed: true);
      _emit();
      unawaited(syncNow());
    } else {
      await _store.saveDraft(draft);
    }
  }

  /// Đóng lần học đang dở (đổi bộ, đổi nhóm, học lại). Không có câu trả lời
  /// nào thì không có gì để ghi.
  void _endDraft() {
    final draft = _draft;
    if (draft == null) return;
    _draft = null;
    unawaited(
      _finish(draft, completed: false).then((_) {
        _emit();
        return syncNow();
      }),
    );
  }

  Future<void> _finish(
    StudySessionRecord draft, {
    required bool completed,
  }) async {
    final record = draft.copyWith(completed: completed);
    _sessions = [..._sessions.where((s) => s.id != record.id), record];
    _pendingSessions = [
      ..._pendingSessions.where((s) => s.id != record.id),
      record,
    ];
    await _store.saveSessions(_sessions);
    await _store.savePendingSessions(_pendingSessions);
    await _store.clearDraft();
  }

  // ------------------------------------------------------------- đồng bộ

  /// Gửi hàng đợi lên server rồi tải nội dung + lịch sử mới nhất về. Không bao
  /// giờ ném lỗi — thất bại chỉ đổi [SyncStatus], lần sau thử lại.
  Future<void> syncNow() async {
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        await _syncOnce();
      } while (_syncAgain);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncOnce() async {
    _syncStatus = SyncStatus.syncing;
    _emit();
    try {
      // 1. Gửi lần học chờ (theo lô, server tự bỏ bản trùng theo id).
      final sessions = [..._pendingSessions];
      for (var i = 0; i < sessions.length; i += 500) {
        await _api.pushSessions(sessions.skip(i).take(500).toList());
      }
      final sentSessions = {for (final s in sessions) s.id};
      _pendingSessions = [
        for (final s in _pendingSessions)
          if (!sentSessions.contains(s.id)) s,
      ];
      await _store.savePendingSessions(_pendingSessions);

      // 2. Gửi ⭐/漢 chờ.
      final flags = [..._pendingFlags];
      for (var i = 0; i < flags.length; i += 1000) {
        await _api.pushFlagChanges(flags.skip(i).take(1000).toList());
      }
      _pendingFlags = _pendingFlags.skip(flags.length).toList();
      await _store.savePendingFlags(_pendingFlags);

      // 3. Nội dung mới nhất (có thể vừa sửa trên máy khác). ⭐/漢 bấm trong
      // lúc đang tải vẫn nằm trong hàng đợi -> áp đè lên bản vừa tải.
      final content = _withPendingFlags(await _api.fetchContent());
      if (jsonEncode(content.toJson()) != jsonEncode(_content.toJson())) {
        await _applyContent(content);
      }

      // 4. Lịch sử học của mọi máy + những lần chưa gửi được của máy này.
      final remote = await _api.fetchSessions();
      final remoteIds = {for (final s in remote) s.id};
      _sessions = [
        ...remote,
        for (final s in _sessions)
          if (!remoteIds.contains(s.id) &&
              _pendingSessions.any((p) => p.id == s.id))
            s,
      ];
      await _store.saveSessions(_sessions);

      _syncStatus = SyncStatus.synced;
    } on ApiException catch (e) {
      _syncStatus = e.offline ? SyncStatus.offline : SyncStatus.error;
    }
    _emit();
  }

  ContentSnapshot _applyFlag(ContentSnapshot content, FlagChange f) =>
      content.updateCard(
        f.cardId,
        (c) => c.copyWith(marked: f.marked, hanja: f.hanja),
      );

  /// Server chưa nhận các ⭐/漢 trong hàng đợi — áp lại lên bản server trả về
  /// để không nháy về giá trị cũ.
  ContentSnapshot _withPendingFlags(ContentSnapshot content) =>
      _pendingFlags.fold(content, _applyFlag);

  /// Thay nội dung (cache + engine) mà không làm mất lượt đang học. Nếu bộ
  /// đang học biến mất (bị xoá trên máy khác) thì lần học dở được chốt lại.
  Future<void> _applyContent(ContentSnapshot content) async {
    _content = content;
    await _store.saveContent(content);
    final e = _engine;
    if (e == null) return;
    final catalog = buildStudyCatalog(content);
    final changedCard = e.replaceContent(
      decks: catalog.decks,
      vocabGroups: catalog.vocabGroups,
      markedIds: catalog.markedIds,
      hanjaIds: catalog.hanjaIds,
    );
    if (_draft != null && _draft!.deckId != e.currentDeckId) _endDraft();
    if (changedCard) _cancelNextLock();
    _emit();
  }

  // ------------------------------------------------------------- học

  void _cancelNextLock() {
    _nextLockTimer?.cancel();
    _nextLockTimer = null;
    _nextLocked = false;
  }

  /// Khoá "Thẻ tiếp" 2 giây sau khi trả lời sai.
  void _startNextLock() {
    _nextLockTimer?.cancel();
    _nextLocked = true;
    _nextLockTimer = Timer(const Duration(seconds: 2), () {
      _nextLocked = false;
      _emit();
    });
  }

  void checkAnswer(String input) {
    final e = _engine;
    if (e == null || e.answered) return;
    if (StudyEngine.normalize(input).isEmpty) return;

    final isCorrect = e.checkAnswer(input);
    if (isCorrect) {
      _cancelNextLock();
      HapticFeedback.lightImpact();
    } else {
      _startNextLock();
      HapticFeedback.heavyImpact();
    }
    _emit();
    unawaited(_recordAnswer());
  }

  void revealAnswer() {
    final e = _engine;
    if (e == null || e.answered) return;
    e.revealAnswer();
    _startNextLock();
    _emit();
    unawaited(_recordAnswer());
  }

  void markKnown() {
    final e = _engine;
    if (e == null || e.answered) return;
    e.markKnown();
    _cancelNextLock();
    _emit();
    unawaited(_recordAnswer());
  }

  void overrideAsCorrect() {
    final e = _engine;
    if (e == null || !e.canOverride) return;
    e.overrideAsCorrect();
    _cancelNextLock();
    _emit();
    unawaited(_recordAnswer());
  }

  void nextCard() {
    final e = _engine;
    if (e == null || _nextLocked) return;
    e.nextCard();
    _cancelNextLock();
    _emit();
  }

  /// ⭐/漢 dùng được cả offline, trên mọi máy: đổi ngay trên máy, gửi sau.
  void toggleMark() => _toggleFlag(marked: true);
  void toggleHanja() => _toggleFlag(marked: false);

  void _toggleFlag({required bool marked}) {
    final e = _engine;
    final cardId = e?.currentWord?.id;
    if (e == null || cardId == null) return;
    final value = marked ? e.toggleMark() : e.toggleHanja();
    if (value == null) return;
    HapticFeedback.selectionClick();

    final change = FlagChange(
      cardId: cardId,
      changedAt: _now(),
      marked: marked ? value : null,
      hanja: marked ? null : value,
    );
    _content = _applyFlag(_content, change);
    _pendingFlags = [..._pendingFlags, change];
    _emit();
    unawaited(() async {
      await _store.saveContent(_content);
      await _store.savePendingFlags(_pendingFlags);
      await syncNow();
    }());
  }

  void switchDeck(String deckId) {
    final e = _engine;
    if (e == null || deckId == e.currentDeckId && deckId != randomDeckId) {
      return;
    }
    _endDraft();
    // Mở lại deck ngẫu nhiên luôn rút một bộ 20 thẻ mới.
    deckId == randomDeckId ? e.reshuffleRandomDeck() : e.switchDeck(deckId);
    _cancelNextLock();
    _emit();
  }

  void switchVocabGroup(String groupId) {
    final e = _engine;
    if (e == null || groupId == e.currentVocabGroup) return;
    _endDraft();
    e.switchVocabGroup(groupId);
    _cancelNextLock();
    _emit();
  }

  void restartDeck() {
    _endDraft();
    _engine?.restartCurrentDeck();
    _cancelNextLock();
    _emit();
  }

  // ------------------------------------------- soạn nội dung (Mac/web, cần mạng)

  /// Chạy một thao tác soạn nội dung trên server rồi áp kết quả vào máy.
  /// Trả về thông báo lỗi để hiển thị, `null` nếu thành công.
  Future<String?> _author(
    Future<ContentSnapshot> Function() action, {
    void Function(StudyEngine)? thenOpen,
  }) async {
    try {
      await _applyContent(_withPendingFlags(await action()));
      final e = _engine;
      if (e != null && thenOpen != null) {
        _endDraft();
        thenOpen(e);
        _cancelNextLock();
        _emit();
      }
      return null;
    } on ApiException catch (e) {
      return e.offline
          ? "Cần có mạng để tạo/sửa nội dung — kiểm tra kết nối rồi thử lại."
          : e.message;
    }
  }

  /// Tạo nhóm rồi mở luôn nhóm đó (đang trống, chờ thêm bộ).
  Future<String?> createGroup(String name) async {
    String? groupId;
    return _author(() async {
      final group = await _api.createGroup(name.trim());
      groupId = group.id;
      return _content.upsertGroup(group);
    }, thenOpen: (e) => e.switchVocabGroup(groupId!));
  }

  Future<String?> renameGroup(String groupId, String name) => _author(
    () async => _content.upsertGroup(await _api.renameGroup(groupId, name)),
  );

  Future<String?> createDeck({
    required String groupId,
    required String name,
    required List<Map<String, dynamic>> words,
  }) async {
    String? deckId;
    return _author(
      () async {
        final deck = await _api.createDeck(
          groupId: groupId,
          name: name,
          words: words,
        );
        deckId = deck.id;
        return _content.upsertDeck(deck);
      },
      thenOpen: (e) {
        if (e.currentVocabGroup != groupId) e.switchVocabGroup(groupId);
        e.switchDeck(deckId!);
      },
    );
  }

  Future<String?> appendCards(
    String deckId,
    List<Map<String, dynamic>> words,
  ) => _author(
    () async => _content.upsertDeck(await _api.appendCards(deckId, words)),
  );

  /// Sửa thẻ đang hiển thị (thẻ trong bộ ảo trỏ về thẻ gốc qua id).
  Future<String?> editCurrentCard({
    required String vi,
    required String kr,
    String? hint,
    List<String> altAnswers = const [],
  }) async {
    final cardId = _engine?.currentWord?.id;
    if (cardId == null) return "Không có thẻ nào đang mở.";
    if (vi.trim().isEmpty || kr.trim().isEmpty) {
      return "Cần đủ nghĩa tiếng Việt và từ tiếng Hàn.";
    }
    final cleanHint = hint?.trim();
    return _author(() async {
      final card = await _api.updateCard(
        cardId,
        kr: kr.trim(),
        vi: vi.trim(),
        hint: cleanHint == null || cleanHint.isEmpty ? null : cleanHint,
        altAnswers: altAnswers,
      );
      return _content.updateCard(cardId, (_) => card);
    });
  }

  /// Xoá thẻ đang hiển thị cùng chuỗi thẻ ngữ cảnh nối sau nó.
  Future<String?> deleteCurrentCard() async {
    final cardId = _engine?.currentWord?.id;
    if (cardId == null) return "Không có thẻ nào đang mở.";
    return _author(() async {
      await _api.deleteCard(cardId);
      return _content.removeCard(cardId);
    });
  }
}
