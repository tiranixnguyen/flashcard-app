// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clock.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Đồng hồ tiêm được — test override để cố định "hôm nay" khi kiểm tra gợi ý
/// ôn lại và thời điểm ghi lần học.

@ProviderFor(clock)
final clockProvider = ClockProvider._();

/// Đồng hồ tiêm được — test override để cố định "hôm nay" khi kiểm tra gợi ý
/// ôn lại và thời điểm ghi lần học.

final class ClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  /// Đồng hồ tiêm được — test override để cố định "hôm nay" khi kiểm tra gợi ý
  /// ôn lại và thời điểm ghi lần học.
  ClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return clock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$clockHash() => r'3b571c5a0c08b7391c0eed04391003191bab6ccf';
