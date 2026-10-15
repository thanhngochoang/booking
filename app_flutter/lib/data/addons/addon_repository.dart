import 'dart:io' show SocketException;

import 'package:photobooking/data/addons/service_addon.dart';

/// A failed add-on callable: server `details.code` and, for form errors,
/// `details.field`.
class AddonException implements Exception {
  const AddonException(this.code, {this.field});
  final String code;
  final String? field;

  @override
  String toString() => 'AddonException($code, $field)';
}

enum AddonErrorCode {
  contactLeak,
  addonLimit,
  invalidArgument,
  permissionDenied,
  notFound,
  network,
  unknown,
}

class AddonError {
  const AddonError(this.code, [this.field]);
  final AddonErrorCode code;

  /// The form field the server blamed (`name`, `description`, `price`, ...).
  final String? field;
}

/// Maps a thrown error to a code and field. Both contact-leak shapes count:
/// the spec's `contact_leak` + field, and #139's `invalid_argument` with
/// field `<field>.contact`.
AddonError addonErrorOf(Object error) {
  if (error is SocketException) return const AddonError(AddonErrorCode.network);
  if (error is! AddonException) return const AddonError(AddonErrorCode.unknown);
  final field = error.field;
  if (error.code == 'invalid_argument' &&
      field != null &&
      field.endsWith('.contact')) {
    return AddonError(
      AddonErrorCode.contactLeak,
      field.substring(0, field.length - '.contact'.length),
    );
  }
  return switch (error.code) {
    'contact_leak' => AddonError(AddonErrorCode.contactLeak, field),
    'addon_limit' => const AddonError(AddonErrorCode.addonLimit),
    'invalid_argument' ||
    'invalid-argument' => AddonError(AddonErrorCode.invalidArgument, field),
    'permission_denied' ||
    'permission-denied' => const AddonError(AddonErrorCode.permissionDenied),
    'not_found' || 'not-found' => const AddonError(AddonErrorCode.notFound),
    'unavailable' ||
    'deadline-exceeded' ||
    'network' => const AddonError(AddonErrorCode.network),
    _ => const AddonError(AddonErrorCode.unknown),
  };
}

abstract class AddonRepository {
  /// Active add-ons of [providerId] for the customer (one-shot read; sorted by
  /// kind, then id). Non-owners can only read active ones.
  Future<List<ServiceAddon>> activeFor(String providerId);

  /// The owner's add-ons, inactive ones too, live.
  Stream<List<ServiceAddon>> watchMine(String uid);

  /// Creates (no [addonId]) or replaces an add-on through `saveAddon`;
  /// returns its id.
  Future<String> save(AddonInput input, {String? addonId});

  Future<void> delete(String addonId);
}
