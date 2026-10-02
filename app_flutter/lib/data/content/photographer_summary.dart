import 'package:photobooking/core/core.dart';

/// What a card or a ranking needs to know about a photographer. Built from the
/// public `users/{uid}` and `photographers/{uid}` documents.
class PhotographerSummary {
  const PhotographerSummary({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.coverUrl,
    this.verified = false,
    this.specialtyIds = const [],
    this.styleIds = const [],
    this.areaLabel,
    this.lat,
    this.lng,
    this.ratingAvg = 0,
    this.reviewCount = 0,
    this.completedCount = 0,
    this.responseMinutes,
    this.startingPriceVnd,
    this.nextFreeDate,
    this.createdAt,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? coverUrl;
  final bool verified;

  /// Taxonomy codes (`portrait`, `wedding`, ...), strongest first.
  final List<String> specialtyIds;

  /// Style codes (`natural_light`, `film`, ...).
  final List<String> styleIds;

  /// City or district shown on cards, e.g. "Quận 1".
  final String? areaLabel;

  /// Centre of the service area; null when the photographer has not set one.
  final double? lat;
  final double? lng;
  final double ratingAvg;
  final int reviewCount;
  final int completedCount;

  /// Median reply time in minutes, when known.
  final int? responseMinutes;

  /// Integer VND, the cheapest active service.
  final int? startingPriceVnd;

  /// First free day as `yyyy-MM-dd` (Vietnam calendar day), computed by the
  /// server into `stats.nextFreeDate`.
  final String? nextFreeDate;
  final DateTime? createdAt;

  bool get hasRating => reviewCount > 0;
  bool get hasGeo => lat != null && lng != null;
  String? get heroUrl => coverUrl ?? avatarUrl;
  DateTime? get nextFreeDay =>
      nextFreeDate == null ? null : parseDayKey(nextFreeDate!);
}
