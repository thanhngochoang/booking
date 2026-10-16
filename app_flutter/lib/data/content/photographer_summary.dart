import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/provider_type.dart';

/// What a card or a ranking needs to know about a photographer. Built from the
/// public `users/{uid}` and `photographers/{uid}` documents.
class PhotographerSummary {
  const PhotographerSummary({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.coverUrl,
    this.verified = false,
    this.businessVerified = false,
    this.acceptingOrders = false,
    this.specialtyIds = const [],
    this.styleIds = const [],
    this.areaLabel,
    this.lat,
    this.lng,
    this.reviewCount = 0,
    this.tomatoCount = 0,
    this.brickCount = 0,
    this.tomatoPct = 0,
    this.score = 0,
    this.completedCount = 0,
    this.responseMinutes,
    this.startingPriceVnd,
    this.nextFreeDate,
    this.createdAt,
    this.providerType = ProviderType.individual,
    this.approvedAwardCount = 0,
    this.studioDistrict,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? coverUrl;
  final bool verified;

  /// A studio whose business record staff approved (S21.04): with [verified]
  /// it earns the gold Studio seal instead of the blue tick (#135 Decision 17).
  final bool businessVerified;

  /// True when the provider can be booked (verified and onboarded); set by the
  /// server. Closed providers show "Chưa nhận đơn" and are left out of Find.
  final bool acceptingOrders;

  /// Taxonomy codes (`portrait`, `wedding`, ...), strongest first.
  final List<String> specialtyIds;

  /// Style codes (`natural_light`, `film`, ...).
  final List<String> styleIds;

  /// City or district shown on cards, e.g. "Quận 1".
  final String? areaLabel;

  /// Centre of the service area; null when the photographer has not set one.
  final double? lat;
  final double? lng;

  /// Tomato and brick reviews; [reviewCount] is their sum.
  final int reviewCount;
  final int tomatoCount;
  final int brickCount;

  /// Share of tomatoes, integer 0..100 (0 without reviews). Show it only when
  /// [hasTomatoPct].
  final int tomatoPct;

  /// Mean signed intensity, -1..1 (0 without reviews); what rankings use.
  final double score;
  final int completedCount;

  /// Median reply time in minutes, when known.
  final int? responseMinutes;

  /// Integer VND, the cheapest active service.
  final int? startingPriceVnd;

  /// First free day as `yyyy-MM-dd` (Vietnam calendar day), computed by the
  /// server into `stats.nextFreeDate`.
  final String? nextFreeDate;
  final DateTime? createdAt;

  /// Individual (default), artist (NAG tier) or studio.
  final ProviderType providerType;
  final int approvedAwardCount;

  /// Public district of a studio; the full address stays private.
  final String? studioDistrict;

  bool get hasReviews => reviewCount > 0;
  bool get hasTomatoPct => reviewCount >= kTomatoPctMinReviews;
  bool get hasGeo => lat != null && lng != null;
  String? get heroUrl => coverUrl ?? avatarUrl;
  DateTime? get nextFreeDay =>
      nextFreeDate == null ? null : parseDayKey(nextFreeDate!);
}
