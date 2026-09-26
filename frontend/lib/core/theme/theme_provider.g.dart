// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(IsDarkMode)
final isDarkModeProvider = IsDarkModeProvider._();

final class IsDarkModeProvider extends $NotifierProvider<IsDarkMode, bool> {
  IsDarkModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isDarkModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isDarkModeHash();

  @$internal
  @override
  IsDarkMode create() => IsDarkMode();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isDarkModeHash() => r'dd910dc745e3a269c173f9e624e2bde552b83e77';

abstract class _$IsDarkMode extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(palette)
final paletteProvider = PaletteProvider._();

final class PaletteProvider
    extends $FunctionalProvider<AppPalette, AppPalette, AppPalette>
    with $Provider<AppPalette> {
  PaletteProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paletteProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paletteHash();

  @$internal
  @override
  $ProviderElement<AppPalette> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppPalette create(Ref ref) {
    return palette(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppPalette value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppPalette>(value),
    );
  }
}

String _$paletteHash() => r'75fe769a19313a171a0834637a3934c0b38b3fc9';
