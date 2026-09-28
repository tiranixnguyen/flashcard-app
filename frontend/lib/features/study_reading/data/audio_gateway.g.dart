// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_gateway.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(audioPlayerGateway)
final audioPlayerGatewayProvider = AudioPlayerGatewayProvider._();

final class AudioPlayerGatewayProvider
    extends
        $FunctionalProvider<
          AudioPlayerGateway,
          AudioPlayerGateway,
          AudioPlayerGateway
        >
    with $Provider<AudioPlayerGateway> {
  AudioPlayerGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioPlayerGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioPlayerGatewayHash();

  @$internal
  @override
  $ProviderElement<AudioPlayerGateway> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AudioPlayerGateway create(Ref ref) {
    return audioPlayerGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioPlayerGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioPlayerGateway>(value),
    );
  }
}

String _$audioPlayerGatewayHash() =>
    r'eac138a126ec644477b633b29f952202a0393632';

@ProviderFor(audioFilePicker)
final audioFilePickerProvider = AudioFilePickerProvider._();

final class AudioFilePickerProvider
    extends
        $FunctionalProvider<AudioFilePicker, AudioFilePicker, AudioFilePicker>
    with $Provider<AudioFilePicker> {
  AudioFilePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioFilePickerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioFilePickerHash();

  @$internal
  @override
  $ProviderElement<AudioFilePicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AudioFilePicker create(Ref ref) {
    return audioFilePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioFilePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioFilePicker>(value),
    );
  }
}

String _$audioFilePickerHash() => r'304f2c55237bd0ed10ecbf9bbde7cc5650ccccd1';
