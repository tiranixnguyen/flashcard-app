import "dart:math";

import "../models/card_progress.dart";
import "../models/deck.dart";
import "../models/study_word.dart";

/// Kết quả của thẻ vừa trả lời.
enum AnswerOutcome {
  /// Chưa trả lời — đang chờ nhập (thẻ tự chấm: chờ lật / chờ tự chấm).
  pending,

  /// Gõ đúng, hoặc thẻ tự chấm bấm "Nhớ".
  correct,

  /// Gõ sai / "Xem đáp án", hoặc thẻ tự chấm bấm "Chưa nhớ".
  wrong,

  /// Người học tự bấm "Đã thuộc" thay vì gõ đáp án.
  known,
}

const markedDeckId = "marked";
const hanjaDeckId = "hanja";
const passageDeckId = "passage";
const randomDeckId = "random20";

bool isVirtualDeckId(String? id) =>
    id == markedDeckId ||
    id == hanjaDeckId ||
    id == passageDeckId ||
    id == randomDeckId;

/// Tên các deck ảo dựng từ cờ (⭐/漢/📖).
const _flaggedDeckNames = {
  markedDeckId: "⭐ Từ khó nhớ",
  hanjaDeckId: "漢 Ôn từ Hán Hàn",
  passageDeckId: "📖 Đoạn văn ngắn",
};

/// Bộ máy học theo kiểu Leitner **trong một lượt học**, thuần Dart (không phụ
/// thuộc Flutter) để test được trực tiếp.
///
/// Không lưu tiến trình giữa các lượt: mỗi lần vào một bộ (đổi bộ, đổi nhóm,
/// học lại, mở lại app) là một lượt mới từ đầu. Thứ được lưu là *lịch sử các
/// lượt* — việc của view model, không phải của engine.
///
/// Engine cố tình giữ trạng thái dạng thay đổi tại chỗ (mutable) vì thuật toán
/// xoay quanh việc chèn/rút thẻ khỏi một hàng đợi; lớp view model bọc ngoài mới
/// là nơi phát ra snapshot bất biến cho UI.
class StudyEngine {
  StudyEngine({
    required this._decks,
    required this._vocabGroups,
    Set<String> markedIds = const {},
    Set<String> hanjaIds = const {},
    Set<String> passageIds = const {},
    Random? random,
  }) : _markedIds = {...markedIds},
       _hanjaIds = {...hanjaIds},
       _passageIds = {...passageIds},
       _random = random ?? Random() {
    _currentVocabGroup = _vocabGroups.isEmpty ? "" : _vocabGroups.first.id;
  }

  /// Số lần đúng liên tiếp để coi là "đã thuộc".
  static const masteryStreak = 3;

  /// Trả lời sai → thẻ quay lại sau 2 thẻ.
  static const wrongOffset = 2;

  /// Trả lời đúng → giãn cách xa dần theo bậc box.
  static const boxOffsets = [3, 5, 9, 15];

  List<Deck> _decks;
  List<VocabGroup> _vocabGroups;
  Set<String> _markedIds;
  Set<String> _hanjaIds;
  Set<String> _passageIds;
  final Random _random;

  final Map<String, Deck> _virtualDecks = {};

  /// Lượt học của bộ đang mở. Chỉ một lượt tại một thời điểm.
  DeckRuntime? _runtime;

  String _currentVocabGroup = "";
  String? _currentDeckId;
  int? _currentId;

  AnswerOutcome _outcome = AnswerOutcome.pending;
  bool _canOverride = false;
  bool _overridden = false;
  bool _flipped = false;
  CardProgress? _answerSnapshot;
  int _cardSerial = 0;

  // ---------------------------------------------------------------- truy vấn

  List<Deck> get decks => _decks;
  List<VocabGroup> get vocabGroups => _vocabGroups;
  String get currentVocabGroup => _currentVocabGroup;
  String? get currentDeckId => _currentDeckId;
  int? get currentIndex => _currentId;

  /// Tăng mỗi khi nạp một lượt hỏi mới (kể cả hỏi lại cùng thẻ, học lại bộ).
  /// UI dựa vào đây để dọn ô nhập — không dựa vào đối tượng thẻ được, vì
  /// [replaceContent] tạo đối tượng mới cho cùng một thẻ đang hỏi dở.
  int get cardSerial => _cardSerial;
  AnswerOutcome get outcome => _outcome;
  bool get answered => _outcome != AnswerOutcome.pending;

  /// Chỉ hiện nút "Thật ra tôi viết đúng" sau khi *gõ* sai, không hiện khi bấm
  /// "Xem đáp án" (lúc đó người học chưa hề trả lời).
  bool get canOverride => _canOverride;

  /// Lượt này đúng nhờ người học tự xác nhận ([overrideAsCorrect]) chứ không
  /// phải gõ khớp — UI vẫn hiện đáp án chuẩn để đối chiếu chính tả.
  bool get overridden => _overridden;

  /// Thẻ tự chấm đã lật (đang hiện mặt sau, chờ tự chấm).
  bool get flipped => _flipped;

  List<Deck> get visibleDecks => _decks
      .where((d) => d.group == _currentVocabGroup)
      .toList(growable: false);

  Deck? deckById(String? id) {
    if (id == null) return null;
    final virtual = _virtualDecks[id];
    if (virtual != null) return virtual;
    for (final d in _decks) {
      if (d.id == id) return d;
    }
    return null;
  }

  Deck? get currentDeck => deckById(_currentDeckId);

  StudyWord? get currentWord {
    final deck = currentDeck;
    final id = _currentId;
    if (deck == null || id == null || id >= deck.words.length) return null;
    return deck.words[id];
  }

  CardProgress? get currentProgress {
    final id = _currentId;
    final rt = _runtime;
    if (id == null || rt == null || id >= rt.cardState.length) return null;
    return rt.cardState[id];
  }

  int get correctCount => _runtime?.correctCount ?? 0;
  int get attemptedCount => _runtime?.attemptedCount ?? 0;
  int get masteredCount => _runtime?.masteredCount ?? 0;
  int get totalCount => currentDeck?.words.length ?? 0;
  int get remainingInRound => (_runtime?.activeQueue.length ?? 0) + 1;

  double get progress => totalCount == 0 ? 0 : masteredCount / totalCount;

  /// Hết thẻ để hỏi: deck rỗng, hoặc đã thuộc hết.
  bool get isCompleted {
    final total = totalCount;
    return total == 0 || masteredCount >= total || _currentId == null;
  }

  bool get currentIsMarked => _markedIds.contains(currentWord?.id);
  bool get currentIsHanja => _hanjaIds.contains(currentWord?.id);
  bool get currentIsPassage => _passageIds.contains(currentWord?.id);

  int get markedCount => _flaggedWords(_markedIds).length;
  int get hanjaCount => _flaggedWords(_hanjaIds).length;
  int get passageCount => _flaggedWords(_passageIds).length;

  // -------------------------------------------------------------- khởi động

  /// Mở bộ đầu tiên của nhóm đầu tiên và nạp thẻ đầu.
  void bootstrap() {
    final visible = visibleDecks;
    _openDeck(visible.isEmpty ? null : visible.first.id);
  }

  /// Bắt đầu lượt mới cho [deckId] (bỏ lượt đang có, nếu có).
  void _openDeck(String? deckId) {
    _currentDeckId = deckId;
    final deck = deckById(deckId);
    _runtime = deck == null
        ? null
        : DeckRuntime(
            cardState: [for (final _ in deck.words) CardProgress()],
            activeQueue: _shuffled([
              for (var i = 0; i < deck.words.length; i++) i,
            ]),
          );
    loadCard();
  }

  /// Học lại deck hiện tại từ đầu — một lượt mới.
  void restartCurrentDeck() {
    final id = _currentDeckId;
    if (id == null) return;
    if (id == randomDeckId) {
      reshuffleRandomDeck();
    } else {
      _openDeck(id);
    }
  }

  // ------------------------------------------------------------ vòng đời thẻ

  void loadCard() {
    _cardSerial++;
    _pruneUnflagged();
    final deck = currentDeck;
    final rt = _runtime;
    if (deck == null || rt == null) {
      _currentId = null;
      return;
    }

    final total = deck.words.length;
    if (total == 0 || rt.masteredCount >= total) {
      _currentId = null;
      return;
    }

    if (rt.activeQueue.isEmpty) {
      // Hàng đợi trống nhưng chưa thuộc hết -> có thẻ bị lệch khỏi hàng đợi.
      // Nạp lại mọi thẻ chưa thuộc thay vì báo hoàn thành nhầm.
      final remaining = [
        for (var i = 0; i < deck.words.length; i++)
          if (!rt.cardState[i].mastered) i,
      ];
      rt.activeQueue.addAll(_shuffled(remaining));
      if (rt.activeQueue.isEmpty) {
        _currentId = null;
        return;
      }
    }

    _currentId = rt.activeQueue.removeAt(0);
    _outcome = AnswerOutcome.pending;
    _canOverride = false;
    _overridden = false;
    _flipped = false;
    _answerSnapshot = rt.cardState[_currentId!].copy();
  }

  void nextCard() => loadCard();

  /// Chuẩn hoá giống bản HTML: bỏ khoảng trắng đầu/cuối, gộp khoảng trắng giữa.
  static String normalize(String input) =>
      input.trim().replaceAll(RegExp(r"\s+"), " ");

  /// Chấm bài. Trả về `true` nếu đúng. Không làm gì nếu thẻ đã được trả lời.
  bool checkAnswer(String input) {
    final rt = _runtime;
    final word = currentWord;
    if (rt == null || word == null || !word.typeAnswer || answered) {
      return false;
    }

    final answer = normalize(input);
    if (answer.isEmpty) return false;

    rt.attemptedCount++;
    final isCorrect = word.matches(answer);
    if (isCorrect) rt.correctCount++;

    _applySchedule(isCorrect);
    _outcome = isCorrect ? AnswerOutcome.correct : AnswerOutcome.wrong;
    _canOverride = !isCorrect;
    return isCorrect;
  }

  /// "Xem đáp án": tính là một lần trả lời sai, nhưng không cho tự xác nhận đúng.
  /// Chỉ cho thẻ gõ đáp án — thẻ tự chấm dùng [flipCard].
  void revealAnswer() {
    final rt = _runtime;
    final word = currentWord;
    if (rt == null || word == null || !word.typeAnswer || answered) return;
    rt.attemptedCount++;
    _applySchedule(false);
    _outcome = AnswerOutcome.wrong;
    _canOverride = false;
  }

  /// Thẻ tự chấm: lật sang mặt sau. Lật **không** phải là trả lời — chưa tính
  /// đúng/sai, chưa đụng tới hàng đợi; người học còn phải tự chấm
  /// ([gradeSelf]).
  void flipCard() {
    final word = currentWord;
    if (word == null || word.typeAnswer || answered) return;
    _flipped = true;
  }

  /// Thẻ tự chấm, sau khi lật: "Nhớ" ([remembered]) đi đúng nhánh gõ đúng,
  /// "Chưa nhớ" đi đúng nhánh gõ sai — cùng lịch ôn, cùng cách tính tỉ lệ
  /// đúng cho gợi ý ôn lại. Không có "Đã trả lời đúng?" (tự chấm rồi còn gì
  /// để sửa).
  void gradeSelf({required bool remembered}) {
    final rt = _runtime;
    final word = currentWord;
    if (rt == null || word == null || word.typeAnswer || !_flipped) return;
    if (answered) return;

    rt.attemptedCount++;
    if (remembered) rt.correctCount++;
    _applySchedule(remembered);
    _outcome = remembered ? AnswerOutcome.correct : AnswerOutcome.wrong;
    _canOverride = false;
  }

  /// "Đã thuộc": đánh dấu thuộc ngay, vẫn hiện đáp án để người học đối chiếu.
  void markKnown() {
    final rt = _runtime;
    final id = _currentId;
    if (rt == null || currentWord == null || id == null || answered) return;

    final cs = rt.cardState[id];
    if (!cs.mastered) {
      cs.mastered = true;
      cs.streak = masteryStreak;
      rt.masteredCount++;
    }
    _outcome = AnswerOutcome.known;
    _canOverride = false;
  }

  /// Người học gõ sai chính tả nhưng thực chất biết từ — hoàn tác nhánh "sai"
  /// rồi áp lại lịch ôn theo hướng "đúng".
  void overrideAsCorrect() {
    final rt = _runtime;
    final id = _currentId;
    if (rt == null || id == null || !_canOverride) return;

    // Gỡ mọi bản ghi của thẻ này khỏi hàng đợi (nhánh "sai" vừa chèn vào).
    rt.activeQueue.removeWhere((q) => q == id);

    // Khôi phục box/streak như trước khi trả lời.
    final snapshot = _answerSnapshot;
    if (snapshot != null) {
      rt.cardState[id]
        ..box = snapshot.box
        ..streak = snapshot.streak;
    }

    rt.correctCount++;
    _applySchedule(true);
    _outcome = AnswerOutcome.correct;
    _canOverride = false;
    _overridden = true;
  }

  void _applySchedule(bool isCorrect) {
    final rt = _runtime;
    final id = _currentId;
    if (rt == null || id == null || currentWord == null) return;

    final cs = rt.cardState[id];
    if (isCorrect) {
      cs.streak++;
      cs.box = min(cs.box + 1, boxOffsets.length - 1);
      if (cs.streak >= masteryStreak) {
        cs.mastered = true;
        rt.masteredCount++;
      } else {
        _insertCard(id, boxOffsets[cs.box]);
      }
    } else {
      cs.box = 0;
      cs.streak = 0;
      _insertCard(id, wrongOffset);
    }
  }

  void _insertCard(int id, int offset) {
    final rt = _runtime;
    if (rt == null) return;
    rt.activeQueue.insert(min(offset, rt.activeQueue.length), id);
  }

  // ----------------------------------------------------------- đánh dấu thẻ

  /// Bật/tắt ⭐ cho thẻ hiện tại, trả về giá trị mới (`null` nếu không có thẻ).
  bool? toggleMark() => _toggleFlag(_markedIds);

  /// Bật/tắt 漢 cho thẻ hiện tại, trả về giá trị mới (`null` nếu không có thẻ).
  bool? toggleHanja() => _toggleFlag(_hanjaIds);

  /// Bật/tắt 📖 cho thẻ hiện tại, trả về giá trị mới (`null` nếu không có thẻ).
  bool? togglePassage() => _toggleFlag(_passageIds);

  /// Tập cờ ứng với deck ảo [deckId] (⭐/漢/📖); `null` nếu không phải.
  Set<String>? _flagsOf(String? deckId) => switch (deckId) {
    markedDeckId => _markedIds,
    hanjaDeckId => _hanjaIds,
    passageDeckId => _passageIds,
    _ => null,
  };

  /// Bỏ cờ ngay trong deck ảo tương ứng thì thẻ vẫn ở lại tới khi sang thẻ
  /// tiếp (xem [_pruneUnflagged]) — để người học xem nốt đáp án, và bấm nhầm
  /// thì bấm lại là xong.
  bool? _toggleFlag(Set<String> flags) {
    final word = currentWord;
    if (word == null) return null;
    if (flags.remove(word.id)) return false;
    flags.add(word.id);
    return true;
  }

  /// Gỡ khỏi deck ⭐/漢 đang mở những thẻ đã bị bỏ cờ trong lượt này. Gọi lúc
  /// nạp thẻ mới, nên thẻ vừa bỏ cờ không bao giờ quay lại và tổng số thẻ
  /// giảm theo — không thì lượt học không bao giờ "hoàn thành" được.
  void _pruneUnflagged() {
    final deckId = _currentDeckId;
    final flags = _flagsOf(deckId);
    final deck = currentDeck;
    final rt = _runtime;
    if (flags == null || deck == null || rt == null) return;
    if (deck.words.every((w) => flags.contains(w.id))) return;

    final pruned = Deck(
      id: deck.id,
      name: deck.name,
      words: [
        for (final w in deck.words)
          if (flags.contains(w.id)) w,
      ],
      isVirtual: true,
    );
    _virtualDecks[deckId!] = pruned;
    _runtime = _carryRuntime(deck, rt, pruned);
  }

  /// Thẻ có cờ trong nhóm đang mở, theo thứ tự bộ/thẻ.
  List<StudyWord> _flaggedWords(Set<String> flags) => [
    for (final deck in visibleDecks)
      for (final w in deck.words)
        if (flags.contains(w.id)) w,
  ];

  // ----------------------------------------------------------- chuyển deck

  /// Mở bộ khác — luôn là một lượt mới, kể cả khi quay lại bộ vừa học dở.
  void switchDeck(String deckId) {
    if (deckId == _currentDeckId) return;
    if (deckId == randomDeckId) {
      _buildRandomDeck();
    } else if (_flagsOf(deckId) case final flags?) {
      _buildFlaggedDeck(deckId, flags);
    }
    _openDeck(deckId);
  }

  void _buildFlaggedDeck(String id, Set<String> flags) {
    _virtualDecks[id] = Deck(
      id: id,
      name: _flaggedDeckNames[id]!,
      words: _flaggedWords(flags),
      isVirtual: true,
    );
  }

  /// 20 thẻ ngẫu nhiên rút từ mọi deck đang hiển thị.
  void _buildRandomDeck() {
    final pool = [for (final deck in visibleDecks) ...deck.words];
    _setRandomDeck(_shuffled(pool).take(20).toList());
  }

  void _setRandomDeck(List<StudyWord> words) {
    _virtualDecks[randomDeckId] = Deck(
      id: randomDeckId,
      name: "🔀 Deck ngẫu nhiên (${words.length})",
      words: words,
      isVirtual: true,
    );
  }

  /// Mở lại deck ngẫu nhiên sẽ rút một bộ 20 thẻ mới.
  void reshuffleRandomDeck() {
    _buildRandomDeck();
    _openDeck(randomDeckId);
  }

  void switchVocabGroup(String groupId) {
    if (groupId == _currentVocabGroup) return;
    _currentVocabGroup = groupId;
    final visible = visibleDecks;
    _openDeck(visible.isEmpty ? null : visible.first.id);
  }

  // ------------------------------------------------------- nội dung thay đổi

  /// Nhận nội dung mới (tải lại từ server, sửa/xoá/thêm thẻ trên Mac/web) mà
  /// không làm mất lượt đang học.
  ///
  /// Tiến trình trong lượt được mang sang **theo id thẻ**: thẻ còn thì giữ
  /// box/streak/đã thuộc và vị trí trong hàng đợi, thẻ bị xoá thì rơi ra, thẻ
  /// mới thêm vào cuối hàng đợi. Nếu bộ đang học không còn (hoặc nhóm không
  /// còn) thì mở bộ đầu tiên của nhóm như lúc khởi động.
  ///
  /// Trả về `true` nếu thẻ đang hiển thị đã đổi sang thẻ khác (view model cần
  /// xoá ô nhập).
  bool replaceContent({
    required List<Deck> decks,
    required List<VocabGroup> vocabGroups,
    required Set<String> markedIds,
    required Set<String> hanjaIds,
    required Set<String> passageIds,
  }) {
    final oldDeck = currentDeck;
    final oldRuntime = _runtime;
    final oldWordId = currentWord?.id;

    _decks = decks;
    _vocabGroups = vocabGroups;
    _markedIds = {...markedIds};
    _hanjaIds = {...hanjaIds};
    _passageIds = {...passageIds};

    if (!vocabGroups.any((g) => g.id == _currentVocabGroup)) {
      _currentVocabGroup = vocabGroups.isEmpty ? "" : vocabGroups.first.id;
      final visible = visibleDecks;
      _openDeck(visible.isEmpty ? null : visible.first.id);
      return true;
    }

    // Dựng lại bộ ảo từ nội dung mới, giữ nguyên danh sách thẻ đã rút.
    final byId = {
      for (final d in decks)
        for (final w in d.words) w.id: w,
    };
    final currentId = _currentDeckId;
    if (currentId == randomDeckId) {
      _setRandomDeck([
        for (final w in oldDeck?.words ?? const <StudyWord>[]) ?byId[w.id],
      ]);
    } else if (_flagsOf(currentId) case final flags?) {
      _buildFlaggedDeck(currentId!, flags);
    }

    final newDeck = currentDeck;
    final belongs =
        newDeck != null &&
        (newDeck.isVirtual || newDeck.group == _currentVocabGroup);
    if (!belongs || oldDeck == null || oldRuntime == null) {
      final visible = visibleDecks;
      _openDeck(visible.isEmpty ? null : visible.first.id);
      return true;
    }

    _runtime = _carryRuntime(oldDeck, oldRuntime, newDeck);
    final newCurrent = newDeck.words.indexWhere((w) => w.id == oldWordId);
    if (oldWordId != null && newCurrent >= 0) {
      _currentId = newCurrent;
      return false;
    }
    if (_currentId == null) return false; // đang ở màn hoàn thành: để yên
    loadCard();
    return true;
  }

  /// Mang lượt đang học từ [oldDeck] sang [newDeck] theo id thẻ: thẻ còn thì
  /// giữ box/streak/đã thuộc và vị trí trong hàng đợi, thẻ bị bỏ thì rơi ra,
  /// thẻ mới xếp (xáo) vào cuối hàng đợi.
  DeckRuntime _carryRuntime(
    Deck oldDeck,
    DeckRuntime oldRuntime,
    Deck newDeck,
  ) {
    final oldIndexOf = {
      for (var i = 0; i < oldDeck.words.length; i++) oldDeck.words[i].id: i,
    };
    final newIndexOf = {
      for (var i = 0; i < newDeck.words.length; i++) newDeck.words[i].id: i,
    };
    final cardState = [
      for (final w in newDeck.words)
        switch (oldIndexOf[w.id]) {
          final old? when old < oldRuntime.cardState.length =>
            oldRuntime.cardState[old],
          _ => CardProgress(),
        },
    ];
    final queue = <int>[
      for (final old in oldRuntime.activeQueue)
        ?newIndexOf[oldDeck.words[old].id],
    ];
    final added = [
      for (var i = 0; i < newDeck.words.length; i++)
        if (!oldIndexOf.containsKey(newDeck.words[i].id)) i,
    ];
    queue.addAll(_shuffled(added));

    return DeckRuntime(
      cardState: cardState,
      activeQueue: queue,
      correctCount: oldRuntime.correctCount,
      attemptedCount: oldRuntime.attemptedCount,
      masteredCount: cardState.where((c) => c.mastered).length,
    );
  }

  List<T> _shuffled<T>(List<T> items) {
    final copy = [...items];
    for (var i = copy.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final tmp = copy[i];
      copy[i] = copy[j];
      copy[j] = tmp;
    }
    return copy;
  }
}
