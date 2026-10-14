// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'link_launcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(linkLauncher)
final linkLauncherProvider = LinkLauncherProvider._();

final class LinkLauncherProvider
    extends $FunctionalProvider<LinkLauncher, LinkLauncher, LinkLauncher>
    with $Provider<LinkLauncher> {
  LinkLauncherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'linkLauncherProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$linkLauncherHash();

  @$internal
  @override
  $ProviderElement<LinkLauncher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LinkLauncher create(Ref ref) {
    return linkLauncher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LinkLauncher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LinkLauncher>(value),
    );
  }
}

String _$linkLauncherHash() => r'6ea1a7aeeb831c4370fc794389bc63b699e2066a';
