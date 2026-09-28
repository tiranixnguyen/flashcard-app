import "dart:async";
import "dart:typed_data";

import "package:file_picker/file_picker.dart";
import "package:just_audio/just_audio.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "audio_gateway.g.dart";

/// Một nhịp trạng thái của trình phát.
class AudioTick {
  const AudioTick({
    this.playing = false,
    this.loading = false,
    this.completed = false,
    this.position = Duration.zero,
    this.duration,
  });

  final bool playing;

  /// Đang tải/đệm — chưa phát ra tiếng.
  final bool loading;

  /// Đã phát tới cuối file.
  final bool completed;
  final Duration position;
  final Duration? duration;
}

/// Trình phát file nghe. Trừu tượng hoá khỏi just_audio để widget test dùng
/// bản giả (just_audio gọi platform channel — test không có, sẽ treo/ném lỗi).
abstract class AudioPlayerGateway {
  Stream<AudioTick> get ticks;

  /// Nạp [url] (bỏ file đang nạp, nếu có). Ném lỗi nếu không tải/đọc được.
  Future<void> load(String url);

  /// Phát tiếp từ vị trí hiện tại. Không chờ phát xong.
  void play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioGateway implements AudioPlayerGateway {
  JustAudioGateway() {
    // Gộp trạng thái phát + vị trí thành một luồng: nút phát cần cả hai.
    _subs = [
      _player.playerStateStream.listen((_) => _emit()),
      _player.positionStream.listen((_) => _emit()),
      _player.durationStream.listen((_) => _emit()),
    ];
  }

  final _player = AudioPlayer();
  final _ticks = StreamController<AudioTick>.broadcast();
  late final List<StreamSubscription<Object?>> _subs;

  void _emit() {
    final state = _player.playerState;
    final processing = state.processingState;
    _ticks.add(
      AudioTick(
        playing: state.playing && processing != ProcessingState.completed,
        loading:
            processing == ProcessingState.loading ||
            processing == ProcessingState.buffering,
        completed: processing == ProcessingState.completed,
        position: _player.position,
        duration: _player.duration,
      ),
    );
  }

  @override
  Stream<AudioTick> get ticks => _ticks.stream;

  @override
  Future<void> load(String url) => _player.setUrl(url);

  // `play()` của just_audio chỉ xong khi dừng/hết bài — không được await.
  @override
  void play() => unawaited(_player.play());

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _ticks.close();
    await _player.dispose();
  }
}

@Riverpod(keepAlive: true)
AudioPlayerGateway audioPlayerGateway(Ref ref) {
  final gateway = JustAudioGateway();
  ref.onDispose(gateway.dispose);
  return gateway;
}

/// File MP3 người dùng chọn để gắn vào thẻ.
class PickedAudio {
  const PickedAudio({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Hộp thoại chọn file — bọc lại để widget test dùng bản giả.
abstract class AudioFilePicker {
  /// `null` nếu người dùng huỷ.
  Future<PickedAudio?> pickMp3();
}

class FilePickerAudioPicker implements AudioFilePicker {
  @override
  Future<PickedAudio?> pickMp3() async {
    final file = await FilePicker.pickFile(
      dialogTitle: "Chọn file nghe (MP3)",
      type: FileType.custom,
      allowedExtensions: const ["mp3"],
    );
    if (file == null) return null;
    return PickedAudio(name: file.name, bytes: await file.readAsBytes());
  }
}

@riverpod
AudioFilePicker audioFilePicker(Ref ref) => FilePickerAudioPicker();
