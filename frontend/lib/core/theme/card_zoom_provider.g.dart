// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_zoom_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Hệ số phóng chữ nội dung trên thẻ (1.0 = cỡ gốc), nhân thêm vào cỡ chữ
/// của hệ điều hành. Chỉ áp cho chữ trên thẻ — nút, header… giữ nguyên cỡ.
/// Lưu riêng từng máy, không đồng bộ.
///
/// keepAlive: màn hoàn thành không có thẻ nào watch; tự huỷ rồi dựng lại thì
/// thẻ sau hiện cỡ gốc một nhịp trước khi đọc xong cài đặt.

@ProviderFor(CardZoom)
final cardZoomProvider = CardZoomProvider._();

/// Hệ số phóng chữ nội dung trên thẻ (1.0 = cỡ gốc), nhân thêm vào cỡ chữ
/// của hệ điều hành. Chỉ áp cho chữ trên thẻ — nút, header… giữ nguyên cỡ.
/// Lưu riêng từng máy, không đồng bộ.
///
/// keepAlive: màn hoàn thành không có thẻ nào watch; tự huỷ rồi dựng lại thì
/// thẻ sau hiện cỡ gốc một nhịp trước khi đọc xong cài đặt.
final class CardZoomProvider extends $NotifierProvider<CardZoom, double> {
  /// Hệ số phóng chữ nội dung trên thẻ (1.0 = cỡ gốc), nhân thêm vào cỡ chữ
  /// của hệ điều hành. Chỉ áp cho chữ trên thẻ — nút, header… giữ nguyên cỡ.
  /// Lưu riêng từng máy, không đồng bộ.
  ///
  /// keepAlive: màn hoàn thành không có thẻ nào watch; tự huỷ rồi dựng lại thì
  /// thẻ sau hiện cỡ gốc một nhịp trước khi đọc xong cài đặt.
  CardZoomProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cardZoomProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cardZoomHash();

  @$internal
  @override
  CardZoom create() => CardZoom();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$cardZoomHash() => r'a20871058e8324ab6607ab328bc7246fa30f6577';

/// Hệ số phóng chữ nội dung trên thẻ (1.0 = cỡ gốc), nhân thêm vào cỡ chữ
/// của hệ điều hành. Chỉ áp cho chữ trên thẻ — nút, header… giữ nguyên cỡ.
/// Lưu riêng từng máy, không đồng bộ.
///
/// keepAlive: màn hoàn thành không có thẻ nào watch; tự huỷ rồi dựng lại thì
/// thẻ sau hiện cỡ gốc một nhịp trước khi đọc xong cài đặt.

abstract class _$CardZoom extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double, double>,
              double,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
