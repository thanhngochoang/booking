import 'package:flutter/foundation.dart';

import 'package:photobooking/data/content/provider_type.dart';

@immutable
class StudioAddressInput {
  const StudioAddressInput({
    required this.line,
    this.ward,
    required this.district,
    required this.city,
    this.lat,
    this.lng,
  });

  final String line;
  final String? ward;
  final String district;
  final String city;
  final double? lat;
  final double? lng;

  /// Callable payload; null fields are left out.
  Map<String, Object> toJson() => {
    'line': line,
    'ward': ?ward,
    'district': district,
    'city': city,
    'lat': ?lat,
    'lng': ?lng,
  };
}

/// Carries the server's error code (`not_eligible`, `invalid_argument`,
/// `not_found`, `permission_denied`, ...).
class ProviderError implements Exception {
  const ProviderError(this.code);
  final String code;

  @override
  String toString() => 'ProviderError($code)';
}

abstract class ProviderRepository {
  /// Throws [ProviderError] with the server code.
  Future<ProviderType> setType(ProviderChoice choice);
  Future<void> setStudioAddress(StudioAddressInput address);

  /// The owner's saved address (private doc), null when none.
  Future<StudioAddressInput?> myStudioAddress(String uid);
}

class FakeProviderRepository implements ProviderRepository {
  FakeProviderRepository({this.type = ProviderType.individual});

  ProviderType type;
  StudioAddressInput? address;

  /// When set, every call throws it.
  ProviderError? failWith;

  /// Every call throws a non-[ProviderError] (network).
  bool failWithNetwork = false;

  /// Called on each [setType] that reaches the server.
  void Function()? onSetType;

  @override
  Future<ProviderType> setType(ProviderChoice choice) async {
    final e = failWith;
    if (e != null) {
      throw e;
    }
    if (failWithNetwork) {
      throw StateError('network');
    }
    onSetType?.call();
    // The server keeps artist for an individual choice.
    if (choice == ProviderChoice.individual && type == ProviderType.artist) {
      return type;
    }
    return type = choice == ProviderChoice.studio
        ? ProviderType.studio
        : ProviderType.individual;
  }

  @override
  Future<void> setStudioAddress(StudioAddressInput a) async {
    final e = failWith;
    if (e != null) {
      throw e;
    }
    if (failWithNetwork) {
      throw StateError('network');
    }
    address = a;
  }

  @override
  Future<StudioAddressInput?> myStudioAddress(String uid) async => address;
}
