import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:freezed_annotation/freezed_annotation.dart' show JsonValue;

/// What an add-on is; decides its icon and its group (S08.06, mock `#S08.07`).
/// Wire code = [name]; order = the server's line order.
enum AddonKind {
  makeup,
  retouch,
  transport,
  outfit,
  other;

  static AddonKind? fromCode(Object? v) {
    for (final k in values) {
      if (k.name == v) return k;
    }
    return null;
  }
}

/// How the price multiplies.
enum AddonUnit {
  @JsonValue('per_booking')
  perBooking('per_booking'),
  @JsonValue('per_person')
  perPerson('per_person'),
  @JsonValue('per_item')
  perItem('per_item');

  const AddonUnit(this.code);

  /// Wire code (snake case).
  final String code;

  static AddonUnit? fromCode(Object? v) {
    for (final u in values) {
      if (u.code == v) return u;
    }
    return null;
  }
}

/// Limits mirrored from `packages/domain/src/addon.ts` (the server decides).
const addonNameMin = 2;
const addonNameMax = 60;
const addonDescriptionMax = 200;
const addonPriceMin = 10000;
const addonPriceMax = 50000000;
const addonMaxQtyLimit = 10;
const maxActiveAddons = 10;

/// What the customer picked: the server prices it (`addonId` + `qty` only).
class AddonPick {
  const AddonPick(this.addonId, this.qty);
  final String addonId;
  final int qty;

  Map<String, dynamic> toPayload() => {'addonId': addonId, 'qty': qty};

  @override
  bool operator ==(Object other) =>
      other is AddonPick && other.addonId == addonId && other.qty == qty;

  @override
  int get hashCode => Object.hash(addonId, qty);
}

/// `photographers/{providerId}/addons/{id}`.
class ServiceAddon {
  const ServiceAddon({
    required this.id,
    required this.providerId,
    required this.kind,
    required this.name,
    this.description,
    required this.price,
    required this.unit,
    required this.maxQty,
    this.serviceIds = const [],
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String providerId;
  final AddonKind kind;
  final String name;
  final String? description;
  final int price;
  final AddonUnit unit;
  final int maxQty;

  /// Packages the add-on applies to; empty = every package.
  final List<String> serviceIds;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool appliesTo(String serviceId) =>
      serviceIds.isEmpty || serviceIds.contains(serviceId);
}

/// Parses an add-on document; null when kind or unit is unknown or a required
/// field is missing. [providerId] comes from the path.
ServiceAddon? serviceAddonFromFirestore(
  String providerId,
  String id,
  Map<String, dynamic>? data,
) {
  if (data == null) return null;
  final kind = AddonKind.fromCode(data['kind']);
  final unit = AddonUnit.fromCode(data['unit']);
  final name = data['name'];
  final price = data['price'];
  if (kind == null || unit == null || name is! String || price is! num) {
    return null;
  }
  DateTime time(Object? v) => v is Timestamp
      ? v.toDate().toUtc()
      : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final description = data['description'];
  final serviceIds = data['serviceIds'];
  return ServiceAddon(
    id: id,
    providerId: providerId,
    kind: kind,
    name: name,
    description: description is String && description.isNotEmpty
        ? description
        : null,
    price: price.toInt(),
    unit: unit,
    maxQty: (data['maxQty'] as num?)?.toInt() ?? 1,
    serviceIds: serviceIds is List
        ? serviceIds.whereType<String>().toList()
        : const [],
    active: data['active'] == true,
    createdAt: time(data['createdAt']),
    updatedAt: time(data['updatedAt']),
  );
}

/// The S08.07 form as sent to `saveAddon`.
class AddonInput {
  const AddonInput({
    required this.kind,
    required this.name,
    this.description,
    required this.price,
    required this.unit,
    this.maxQty = 1,
    this.choosePackages = false,
    this.serviceIds = const [],
    this.active = true,
  });

  final AddonKind kind;
  final String name;
  final String? description;
  final int price;
  final AddonUnit unit;
  final int maxQty;

  /// "Chọn gói" instead of "Mọi gói".
  final bool choosePackages;
  final List<String> serviceIds;
  final bool active;

  /// The callable payload; `maxQty` is 1 for `per_booking`, and an
  /// all-packages add-on sends no ids.
  Map<String, dynamic> toPayload({String? addonId}) => {
    'addonId': ?addonId,
    'kind': kind.name,
    'name': name.trim(),
    if (description != null && description!.trim().isNotEmpty)
      'description': description!.trim(),
    'price': price,
    'unit': unit.code,
    'maxQty': unit == AddonUnit.perBooking ? 1 : maxQty,
    'serviceIds': choosePackages ? serviceIds : const <String>[],
    'active': active,
  };
}

enum AddonInputError {
  nameLength,
  descriptionLength,
  priceRange,
  maxQtyRange,
  contact,
  packagesEmpty,
}

final _contactPattern = RegExp(
  r'(?:\+?\d[\s.\-]?){9,}|https?://|www\.|@|\b[\w-]+\.(?:com|vn|me|net|org)\b|zalo|whatsapp|telegram|viber|facebook|fb\.',
  caseSensitive: false,
);

/// Mirror of the server's `validateAddonInput` limits, for inline form errors;
/// the server stays the authority. Returns the first problem, or null.
AddonInputError? validateAddonInput(AddonInput input) {
  String clean(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');
  final name = clean(input.name);
  final length = name.characters.length;
  if (length < addonNameMin || length > addonNameMax) {
    return AddonInputError.nameLength;
  }
  final description = clean(input.description ?? '');
  if (description.characters.length > addonDescriptionMax) {
    return AddonInputError.descriptionLength;
  }
  if (_contactPattern.hasMatch(name) || _contactPattern.hasMatch(description)) {
    return AddonInputError.contact;
  }
  if (input.price < addonPriceMin || input.price > addonPriceMax) {
    return AddonInputError.priceRange;
  }
  if (input.unit != AddonUnit.perBooking &&
      (input.maxQty < 1 || input.maxQty > addonMaxQtyLimit)) {
    return AddonInputError.maxQtyRange;
  }
  if (input.choosePackages && input.serviceIds.isEmpty) {
    return AddonInputError.packagesEmpty;
  }
  return null;
}
