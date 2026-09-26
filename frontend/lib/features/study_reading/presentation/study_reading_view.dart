import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/rendering.dart" show RenderAbstractViewport;
import "package:flutter/services.dart"
    show HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/platform/platform.dart";
import "../../../core/theme/app_palette.dart";
import "../../../core/theme/theme_provider.dart";
import "study_session_view_model.dart";
import "widgets/deck_navigation.dart";
import "widgets/study_card.dart";
import "widgets/study_header.dart";
import "widgets/study_panels.dart";

class StudyReadingView extends ConsumerStatefulWidget {
  const StudyReadingView({super.key});

  @override
  ConsumerState<StudyReadingView> createState() => _StudyReadingViewState();
}

class _StudyReadingViewState extends ConsumerState<StudyReadingView>
    with WidgetsBindingObserver {
  final _answerController = TextEditingController();
  final _answerFocus = FocusNode();

  final _pageScroll = ScrollController();
  final _deckPickerKey = GlobalKey();
  final _answerRowKey = GlobalKey();
  Timer? _typingScrollDebounce;

  /// Lượt hỏi lúc ô nhập được dọn lần cuối — dùng để biết khi nào engine đã
  /// chuyển sang thẻ khác và ô nhập cần trống trở lại.
  int? _shownCardSerial;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleShortcut);
    WidgetsBinding.instance.addObserver(this);
    _answerFocus.addListener(_onAnswerFocusChange);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleShortcut);
    WidgetsBinding.instance.removeObserver(this);
    _typingScrollDebounce?.cancel();
    _pageScroll.dispose();
    _answerController.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  StudySessionViewModel get _vm =>
      ref.read(studySessionViewModelProvider.notifier);

  // ------------------------------------------------ tự cuộn khi gõ (điện thoại)

  void _onAnswerFocusChange() {
    if (_answerFocus.hasFocus) _scheduleTypingScroll();
  }

  /// Bàn phím trồi lên/thụt xuống làm đổi vùng nhìn thấy -> tính lại.
  @override
  void didChangeMetrics() {
    if (_answerFocus.hasFocus) _scheduleTypingScroll();
  }

  /// Chờ bàn phím mở xong (metrics đổi liên tục trong lúc animation) rồi mới
  /// cuộn một lần, để khỏi giật và khỏi bị cú cuộn "lộ caret" mặc định của
  /// TextField đè lên.
  void _scheduleTypingScroll() {
    if (!isPhone) return;
    _typingScrollDebounce?.cancel();
    _typingScrollDebounce = Timer(
      const Duration(milliseconds: 300),
      _scrollForTyping,
    );
  }

  /// Cuộn xuống thấp nhất có thể mà ô chọn bộ từ (tên deck) vẫn còn thấy:
  /// đưa mép trên ô chọn bộ từ lên sát mép trên vùng nhìn thấy. Nếu màn quá
  /// thấp không đủ chỗ cho cả ô chọn bộ từ lẫn ô nhập, ưu tiên ô nhập — không
  /// thể bắt người học gõ khi không thấy mình đang gõ gì.
  void _scrollForTyping() {
    if (!mounted || !_answerFocus.hasFocus || !_pageScroll.hasClients) return;
    final picker = _deckPickerKey.currentContext?.findRenderObject();
    final input = _answerRowKey.currentContext?.findRenderObject();
    if (picker == null || input == null) return;

    final viewport = RenderAbstractViewport.of(picker);
    const topGap = 8.0; // để viền trên của ô chọn bộ từ không bị cắt sát mép
    const inputBottomGap = 20.0; // bằng scrollPadding mặc định của TextField
    final keepPickerVisible =
        viewport.getOffsetToReveal(picker, 0).offset - topGap;
    final keepInputVisible =
        viewport.getOffsetToReveal(input, 1).offset + inputBottomGap;

    final position = _pageScroll.position;
    final target =
        (keepInputVisible > keepPickerVisible
                ? keepInputVisible
                : keepPickerVisible)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 1) return;
    _pageScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Phím tắt (macOS + web):
  /// - Chưa trả lời: `Cmd+Enter` = Đã thuộc, `Cmd+/` = Xem đáp án,
  ///   `Enter` = chấm bài (do chính TextField xử lý, handler này bỏ qua).
  /// - Đã trả lời: `Enter` hoặc `Cmd+Enter` = Thẻ tiếp (vẫn tôn trọng khoá
  ///   2 giây sau khi sai — `nextCard()` tự bỏ qua lúc đang khoá).
  /// `Ctrl` được coi như `Cmd` (web trên Windows/Linux), giống bản HTML gốc.
  ///
  /// Bắt ở cấp HardwareKeyboard chứ không dùng Shortcuts/Focus: sau khi trả
  /// lời, ô nhập bị vô hiệu hoá và mất focus, nên cơ chế dựa trên focus sẽ
  /// không nhận được `Enter` để sang thẻ tiếp — đúng lỗi của bản trước.
  bool _handleShortcut(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    // Đang mở dialog sửa thẻ hoặc menu ••• -> route trên cùng không phải màn
    // học; để phím về cho dialog/menu (vd Enter trong ô sửa thẻ).
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    final s = ref.read(studySessionViewModelProvider).value;
    if (s == null || s.word == null) return false;

    final keyboard = HardwareKeyboard.instance;
    final withCmd = keyboard.isMetaPressed || keyboard.isControlPressed;
    final key = event.logicalKey;
    final isEnter =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;

    if (withCmd && key == LogicalKeyboardKey.slash) {
      if (s.answered) return false;
      _vm.revealAnswer();
      return true;
    }
    if (isEnter) {
      if (s.answered) {
        _vm.nextCard();
        return true;
      }
      if (withCmd) {
        _vm.markKnown();
        return true;
      }
      // Enter thường khi chưa trả lời: để TextField chấm bài như cũ (và để
      // bộ gõ tiếng Hàn chốt chữ đang soạn dở trước).
    }
    return false;
  }

  /// Dọn ô nhập khi engine chuyển sang thẻ mới. Không dùng `nextCard()` để làm
  /// việc này vì thẻ còn đổi qua nhiều đường khác: xoá thẻ, đổi deck, đổi nhóm,
  /// học lại từ đầu, nội dung tải lại từ server.
  void _syncInputWithCard(StudySessionState s) {
    if (s.cardSerial == _shownCardSerial) return;
    _shownCardSerial = s.cardSerial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _answerController.clear();
      if (s.word != null) _answerFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final isDark = ref.watch(isDarkModeProvider);
    final async = ref.watch(studySessionViewModelProvider);

    return Scaffold(
      backgroundColor: palette.paper,
      body: SafeArea(
        // Không dùng Center bọc chung cho mọi trạng thái: màn "đã thuộc hết"
        // (thẻ ngắn) và màn đang học (thẻ + 2 hàng nút + footer) có chiều cao
        // nội dung khác hẳn nhau, Center sẽ canh giữa THEO CHIỀU DỌC cả khối,
        // khiến nội dung "nhảy" vị trí giữa hai màn hình — ngắn thì trôi
        // xuống giữa cửa sổ, dài thì bị đẩy lên trên. Ghim theo mép trên
        // (Align topCenter) để vị trí luôn ổn định, chỉ chiều rộng mới canh
        // giữa. Riêng lúc đang tải thì vẫn canh giữa cả cửa sổ — spinner nằm
        // giữa màn hình mới đúng quy ước, không cần ổn định vị trí vì nó chỉ
        // hiện thoáng qua.
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: LoadErrorView(error: e, palette: palette),
            ),
          ),
          data: (s) => Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _body(palette, isDark, s),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(AppPalette p, bool isDark, StudySessionState s) {
    _syncInputWithCard(s);

    // Trên màn hẹp, padding màn hình 20 cộng padding thẻ 24 ăn mất 44pt mỗi
    // bên; thu lại để chữ có chỗ thở.
    final narrow = MediaQuery.sizeOf(context).width < 400;
    final gutter = narrow ? 14.0 : 20.0;

    return SingleChildScrollView(
      controller: _pageScroll,
      padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudyHeader(state: s, palette: p, isDark: isDark),
          const SizedBox(height: 14),
          GroupTabs(state: s, palette: p),
          const SizedBox(height: 10),
          DeckPicker(key: _deckPickerKey, state: s, palette: p),
          if (!isPhone) AuthoringRow(state: s, palette: p),
          const SizedBox(height: 12),
          if (s.isEmptyGroup)
            EmptyStateView(
              palette: p,
              title: "Nhóm này chưa có bộ từ nào",
              message: isPhone
                  ? "Chọn một nhóm khác ở phía trên để bắt đầu học. "
                        "Bộ từ mới được tạo trên Mac/web."
                  : "Bấm “+ Bộ mới” để tạo bộ đầu tiên, hoặc chọn nhóm khác.",
            )
          else if (s.isEmptyDeck)
            EmptyStateView(
              palette: p,
              title: "Bộ này chưa có thẻ nào",
              message: s.isVirtualDeck
                  ? "Chọn một bộ khác ở phía trên để tiếp tục học."
                  : isPhone
                  ? "Thẻ mới được thêm trên Mac/web."
                  : "Bấm “+ Thêm từ vào bộ này” để thêm thẻ.",
            )
          else ...[
            StatsRow(state: s, palette: p),
            const SizedBox(height: 8),
            MasteryProgressBar(progress: s.progress, palette: p),
            const SizedBox(height: 20),
            if (s.isCompleted)
              CompletionView(state: s, palette: p)
            else
              StudyCard(
                state: s,
                palette: p,
                narrow: narrow,
                answerController: _answerController,
                answerFocus: _answerFocus,
                answerRowKey: _answerRowKey,
              ),
            const SizedBox(height: 16),
            if (!s.isCompleted) StudyControls(state: s, palette: p),
            const SizedBox(height: 18),
            RestartFooter(palette: p),
          ],
        ],
      ),
    );
  }
}
