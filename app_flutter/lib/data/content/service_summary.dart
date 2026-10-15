/// A bookable package (`photographers/{uid}/services/{id}`).
class ServiceSummary {
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
  });

  final String id;
  final String photographerId;
  final String name;
  final String? specialtyId;

  /// Integer VND, always greater than zero.
  final int priceVnd;
  final int durationMinutes;
  final int? photoCount;
  final int? editedCount;
  final int? deliveryDays;
  final String? coverUrl;
  final bool active;
}
