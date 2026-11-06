import 'package:photobooking/data/pricing/day_pricing.dart';

/// A bookable package (`photographers/{uid}/services/{id}`). It is priced by
/// day like the owner's `ServicePackage`: [priceVnd] is the weekday price and
/// [dayPrices] and [specialPrice] refine it (#316).
class ServiceSummary implements PricedService {
  const ServiceSummary({
    required this.id,
    required this.photographerId,
    required this.name,
    this.specialtyId,
    required this.priceVnd,
    required this.durationMinutes,
    this.photoCount,
    this.editedCount,
    this.deliveryDays,
    this.coverUrl,
    this.active = true,
    this.dayPrices,
    this.specialPrice,
  });

  final String id;
  final String photographerId;
  final String name;
  final String? specialtyId;

  /// Integer VND, always greater than zero.
  final int priceVnd;

  @override
  int get price => priceVnd;

  /// Price per weekday; null for one price on all days.
  @override
  final Map<Weekday, int>? dayPrices;

  /// Price on special days (holidays and the provider's own ranges).
  @override
  final int? specialPrice;
  final int durationMinutes;
  final int? photoCount;
  final int? editedCount;
  final int? deliveryDays;
  final String? coverUrl;
  final bool active;
}
