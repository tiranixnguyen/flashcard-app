import "package:riverpod_annotation/riverpod_annotation.dart";

import "../data/audio_gateway.dart";
import "../models/card_audio.dart";
import "../models/study_word.dart";

part "audio_playback.g.dart";

class AudioPlaybackState {
  const AudioPlaybackState({
    this.url,
    this.tick = const AudioTick(),
    this.failedUrl,
  });

  /// File đang nạp/phát/tạm dừng; `null` = không có gì.
  final String? url;
  final AudioTick tick;

  /// File vừa phát lỗi (mất mạng, file hỏng) — nút của nó hiện dấu lỗi.
  final String? failedUrl;
}

/// Trình phát dùng chung cho cả màn học lẫn dialog sửa thẻ: mỗi lúc chỉ một
/// file, bấm file khác thì file đang phát dừng.
@Riverpod(keepAlive: true)
class AudioPlayback extends _$AudioPlayback {
  AudioPlayerGateway get _player => ref.read(audioPlayerGatewayProvider);

  @override
  AudioPlaybackState build() {
    final sub = ref.watch(audioPlayerGatewayProvider).ticks.listen((tick) {
      if (state.url != null) {
        state = AudioPlaybackState(url: state.url, tick: tick);
      }
    });
    ref.onDispose(sub.cancel);
    return const AudioPlaybackState();
  }

  /// Bấm nút của [url]: đang phát thì tạm dừng, đang dừng thì phát tiếp (hết
  /// bài thì phát lại từ đầu), file khác thì chuyển sang file này.
  Future<void> toggle(String url) async {
    if (state.url == url) {
      final tick = state.tick;
      if (tick.playing) return _player.pause();
      if (tick.completed) await _player.seek(Duration.zero);
      _player.play();
      return;
    }
    state = AudioPlaybackState(url: url, tick: const AudioTick(loading: true));
    try {
      await _player.load(url);
    } on Object {
      if (state.url == url) state = AudioPlaybackState(failedUrl: url);
      return;
    }
    // Trong lúc nạp, người dùng có thể đã bấm file khác hoặc sang thẻ khác.
    if (state.url == url) _player.play();
  }

  /// Dừng hẳn — gọi khi sang thẻ khác, để tiếng thẻ cũ không đè lên thẻ mới.
  Future<void> stop() async {
    if (state.url == null && state.failedUrl == null) return;
    state = const AudioPlaybackState();
    await _player.stop();
  }
}

/// Các trường có file nghe đang hiện trên thẻ, theo thứ tự ưu tiên của phím
/// tắt `Cmd+.`: đã lộ đáp án thì mặt sau trước, chưa lộ thì mặt trước.
List<CardField> visibleAudioFields(StudyWord word, {required bool revealed}) {
  final shown = revealed
      ? [
          CardField.back,
          if (word.note != null) CardField.note,
          CardField.front,
          if (word.hint != null) CardField.hint,
        ]
      : [CardField.front, if (word.hint != null) CardField.hint];
  return [
    for (final f in shown)
      if (word.audio[f] != null) f,
  ];
}
