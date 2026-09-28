import "dart:async";

import "package:flashcard_app/features/study_reading/data/audio_gateway.dart";
import "package:flashcard_app/features/study_reading/models/card_audio.dart";
import "package:flashcard_app/features/study_reading/models/study_word.dart";
import "package:flashcard_app/features/study_reading/presentation/audio_playback.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

import "support/fake_audio.dart";

void main() {
  late FakeAudioGateway player;
  late ProviderContainer container;
  AudioPlayback notifier() => container.read(audioPlaybackProvider.notifier);
  AudioPlaybackState state() => container.read(audioPlaybackProvider);

  /// Để tick (stream broadcast, bắn bất đồng bộ) tới notifier.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() {
    player = FakeAudioGateway();
    container = ProviderContainer(
      overrides: [audioPlayerGatewayProvider.overrideWithValue(player)],
    );
    // Giữ provider sống + đăng ký nghe tick ngay từ đầu.
    container.listen(audioPlaybackProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  test("bấm là nạp + phát; bấm lại tạm dừng rồi phát tiếp", () async {
    await notifier().toggle("u1");
    await flush();
    expect(player.loaded, "u1");
    expect(state().url, "u1");
    expect(state().tick.playing, isTrue);

    await notifier().toggle("u1");
    await flush();
    expect(player.playing, isFalse);
    expect(state().tick.playing, isFalse);
    expect(state().url, "u1");

    await notifier().toggle("u1");
    await flush();
    expect(player.playing, isTrue);
    expect(player.seeks, isEmpty); // phát tiếp, không tua về đầu
  });

  test("hết bài bấm lại thì phát từ đầu", () async {
    await notifier().toggle("u1");
    player.finish();
    await flush();
    expect(state().tick.completed, isTrue);

    await notifier().toggle("u1");
    expect(player.seeks, [Duration.zero]);
    expect(player.playing, isTrue);
  });

  test("bấm file khác thì chuyển sang file đó", () async {
    await notifier().toggle("u1");
    await notifier().toggle("u2");
    await flush();
    expect(player.loaded, "u2");
    expect(state().url, "u2");
  });

  test(
    "nạp lỗi -> đánh dấu file lỗi, không kẹt ở trạng thái đang tải",
    () async {
      player.failing.add("hong");
      await notifier().toggle("hong");
      expect(state().url, isNull);
      expect(state().failedUrl, "hong");
      // Bấm lại là thử lại.
      player.failing.clear();
      await notifier().toggle("hong");
      expect(state().failedUrl, isNull);
      expect(player.loaded, "hong");
    },
  );

  test("sang thẻ khác lúc đang nạp -> nạp xong cũng không phát", () async {
    player.loadGate = Completer();
    final loading = notifier().toggle("u1");
    expect(state().tick.loading, isTrue);
    await notifier().stop();
    player.loadGate!.complete();
    await loading;
    expect(player.playing, isFalse);
    expect(state().url, isNull);
  });

  test("stop khi không phát gì thì không đụng trình phát", () async {
    await notifier().stop();
    expect(player.stops, 0);
    await notifier().toggle("u1");
    await notifier().stop();
    expect(player.stops, 1);
    await flush();
    expect(state().url, isNull); // tick tới sau khi dừng bị bỏ qua
  });

  group("visibleAudioFields (phím tắt Cmd+.)", () {
    const all = CardAudio({
      CardField.front: "f",
      CardField.back: "b",
      CardField.hint: "h",
      CardField.note: "n",
    });
    const word = StudyWord(
      id: "c",
      front: "đi",
      back: "가다",
      hint: "gợi ý",
      note: "giải thích",
      audio: all,
    );

    test("chưa lộ đáp án: chỉ mặt trước/gợi ý, mặt trước trước", () {
      expect(visibleAudioFields(word, revealed: false), [
        CardField.front,
        CardField.hint,
      ]);
    });

    test("đã lộ: mặt sau trước", () {
      expect(visibleAudioFields(word, revealed: true).first, CardField.back);
    });

    test("trường không hiện trên thẻ (không có chữ) thì bỏ qua", () {
      const bare = StudyWord(id: "c", front: "đi", back: "가다", audio: all);
      expect(visibleAudioFields(bare, revealed: true), [
        CardField.back,
        CardField.front,
      ]);
    });
  });
}
