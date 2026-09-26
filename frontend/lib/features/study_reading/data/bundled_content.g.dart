// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bundled_content.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bundledContent)
final bundledContentProvider = BundledContentProvider._();

final class BundledContentProvider
    extends $FunctionalProvider<BundledContent, BundledContent, BundledContent>
    with $Provider<BundledContent> {
  BundledContentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bundledContentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bundledContentHash();

  @$internal
  @override
  $ProviderElement<BundledContent> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BundledContent create(Ref ref) {
    return bundledContent(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BundledContent value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BundledContent>(value),
    );
  }
}

String _$bundledContentHash() => r'2e6e8762159c1accb89a6c3b0074e6f0df723343';
