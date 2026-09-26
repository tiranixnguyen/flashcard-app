// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(contentApi)
final contentApiProvider = ContentApiProvider._();

final class ContentApiProvider
    extends $FunctionalProvider<ContentApi, ContentApi, ContentApi>
    with $Provider<ContentApi> {
  ContentApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentApiHash();

  @$internal
  @override
  $ProviderElement<ContentApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ContentApi create(Ref ref) {
    return contentApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContentApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContentApi>(value),
    );
  }
}

String _$contentApiHash() => r'757fcc7bf734565634af50220d26c3740e39de77';
