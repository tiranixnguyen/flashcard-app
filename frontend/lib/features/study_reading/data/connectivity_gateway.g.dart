// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity_gateway.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(connectivityGateway)
final connectivityGatewayProvider = ConnectivityGatewayProvider._();

final class ConnectivityGatewayProvider
    extends
        $FunctionalProvider<
          ConnectivityGateway,
          ConnectivityGateway,
          ConnectivityGateway
        >
    with $Provider<ConnectivityGateway> {
  ConnectivityGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityGatewayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityGatewayHash();

  @$internal
  @override
  $ProviderElement<ConnectivityGateway> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConnectivityGateway create(Ref ref) {
    return connectivityGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectivityGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectivityGateway>(value),
    );
  }
}

String _$connectivityGatewayHash() =>
    r'7762a15a0d0732731eb58e238e77f5b9666f434e';
