import "dart:async";
import "dart:typed_data";

import "package:flashcard_app/features/study_reading/data/audio_gateway.dart";

/// Trình phát giả: ghi lại lệnh, tự bắn [AudioTick] như just_audio. Widget
/// test phải override `audioPlayerGatewayProvider` bằng cái này — just_audio
/// thật gọi platform channel, test không có.
class FakeAudioGateway implements AudioPlayerGateway {
  final _ticks = StreamController<AudioTick>.broadcast();

  /// File nạp lỗi (mất mạng, file hỏng).
  final failing = <String>{};

  /// Nạp xong thì chờ cái này (null = xong ngay) — để test bấm file khác
  /// trong lúc đang nạp.
  Completer<void>? loadGate;

  String? loaded;
  bool playing = false;
  int stops = 0;
  final seeks = <Duration>[];

  static const duration = Duration(seconds: 10);

  void _tick({bool completed = false}) => _ticks.add(
    AudioTick(playing: playing, completed: completed, duration: duration),
  );

  /// Mô phỏng phát tới cuối file.
  void finish() {
    playing = false;
    _tick(completed: true);
  }

  @override
  Stream<AudioTick> get ticks => _ticks.stream;

  @override
  Future<void> load(String url) async {
    await loadGate?.future;
    if (failing.contains(url)) throw Exception("không tải được $url");
    loaded = url;
  }

  @override
  void play() {
    playing = true;
    _tick();
  }

  @override
  Future<void> pause() async {
    playing = false;
    _tick();
  }

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  Future<void> stop() async {
    playing = false;
    stops++;
  }

  @override
  Future<void> dispose() => _ticks.close();
}

class FakeAudioPicker implements AudioFilePicker {
  /// `null` = người dùng bấm Huỷ.
  PickedAudio? next = PickedAudio(
    name: "voice.mp3",
    bytes: Uint8List.fromList([0x49, 0x44, 0x33, 0x04]),
  );
  int picks = 0;

  @override
  Future<PickedAudio?> pickMp3() async {
    picks++;
    return next;
  }
}
