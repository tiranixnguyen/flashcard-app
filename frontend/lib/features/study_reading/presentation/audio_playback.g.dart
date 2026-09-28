// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_playback.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Trình phát dùng chung cho cả màn học lẫn dialog sửa thẻ: mỗi lúc chỉ một
/// file, bấm file khác thì file đang phát dừng.

@ProviderFor(AudioPlayback)
final audioPlaybackProvider = AudioPlaybackProvider._();

/// Trình phát dùng chung cho cả màn học lẫn dialog sửa thẻ: mỗi lúc chỉ một
/// file, bấm file khác thì file đang phát dừng.
final class AudioPlaybackProvider
    extends $NotifierProvider<AudioPlayback, AudioPlaybackState> {
  /// Trình phát dùng chung cho cả màn học lẫn dialog sửa thẻ: mỗi lúc chỉ một
  /// file, bấm file khác thì file đang phát dừng.
  AudioPlaybackProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioPlaybackProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioPlaybackHash();

  @$internal
  @override
  AudioPlayback create() => AudioPlayback();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioPlaybackState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioPlaybackState>(value),
    );
  }
}

String _$audioPlaybackHash() => r'7c29c719b5ae22faab3ee92fa15206722dbbbcac';

/// Trình phát dùng chung cho cả màn học lẫn dialog sửa thẻ: mỗi lúc chỉ một
/// file, bấm file khác thì file đang phát dừng.

abstract class _$AudioPlayback extends $Notifier<AudioPlaybackState> {
  AudioPlaybackState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AudioPlaybackState, AudioPlaybackState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AudioPlaybackState, AudioPlaybackState>,
              AudioPlaybackState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
