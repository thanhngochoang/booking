import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:photobooking/data/booking/booking_status.dart';

part 'booking.freezed.dart';
part 'booking.g.dart';

enum EscrowStatus {
  held,
  released,
  disputed,
  refunded,
  @JsonValue('partially_refunded')
  partiallyRefunded,
}

@freezed
abstract class BookingServiceSnapshot with _$BookingServiceSnapshot {
  const factory BookingServiceSnapshot({
    required String name,
    required int price,
    required int durationMinutes,
  }) = _BookingServiceSnapshot;

  factory BookingServiceSnapshot.fromJson(Map<String, dynamic> json) =>
      _$BookingServiceSnapshotFromJson(json);
}

@freezed
abstract class BookingPlace with _$BookingPlace {
  const factory BookingPlace({required String name, double? lat, double? lng}) =
      _BookingPlace;

  factory BookingPlace.fromJson(Map<String, dynamic> json) =>
      _$BookingPlaceFromJson(json);
}

@freezed
abstract class BookingCancel with _$BookingCancel {
  const factory BookingCancel({
    required String by,
    String? reason,
    required DateTime at,
    required int refundPercent,
  }) = _BookingCancel;

  factory BookingCancel.fromJson(Map<String, dynamic> json) =>
      _$BookingCancelFromJson(json);
}

@freezed
abstract class BookingContactSnapshot with _$BookingContactSnapshot {
  const factory BookingContactSnapshot({
    required String name,
    String? phone,
    @Default(true) bool allowZalo,
    @Default(false) bool allowWhatsApp,
    DateTime? redactedAt,
  }) = _BookingContactSnapshot;

  factory BookingContactSnapshot.fromJson(Map<String, dynamic> json) =>
      _$BookingContactSnapshotFromJson(json);
}

@freezed
abstract class BookingEventRecord with _$BookingEventRecord {
  const factory BookingEventRecord({
    required String id,
    required String bookingId,
    required BookingStatus status,
    required DateTime at,
    String? actorId,
  }) = _BookingEventRecord;

  factory BookingEventRecord.fromJson(Map<String, dynamic> json) =>
      _$BookingEventRecordFromJson(json);
}

@freezed
abstract class Booking with _$Booking {
  const Booking._();
  const factory Booking({
    required String id,
    required String customerId,
    required String photographerId,
    required String serviceId,
    required BookingServiceSnapshot serviceSnapshot,
    required String day,
    required String start,
    required String end,
    required BookingPlace place,
    String? note,
    required BookingStatus status,
    required int deposit,
    required int remaining,
    EscrowStatus? escrowStatus,
    int? depositRefunded,
    String? depositProvider,
    DateTime? depositPaidAt,
    DateTime? depositRefundedAt,
    DateTime? acceptDeadline,
    BookingCancel? cancel,
    DateTime? completedAt,
    DateTime? reviewedAt,
    String? chatId,
    @Default(1) int version,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Booking;

  factory Booking.fromJson(Map<String, dynamic> json) =>
      _$BookingFromJson(json);
}

/// Converts Firestore document snapshot to [Booking].
Booking? bookingFromFirestore(String id, Map<String, dynamic>? data) {
  if (data == null) return null;

  DateTime? toDateTime(Object? val) {
    if (val is Timestamp) return val.toDate().toUtc();
    if (val is DateTime) return val.toUtc();
    if (val is String) return DateTime.tryParse(val)?.toUtc();
    return null;
  }

  try {
    final serviceRaw = data['serviceSnapshot'] ?? data['service'];
    if (serviceRaw is! Map<String, dynamic>) return null;

    final placeRaw = data['place'] ?? data['location'];
    BookingPlace place;
    if (placeRaw is Map<String, dynamic>) {
      double? lat;
      double? lng;
      final point = placeRaw['point'];
      if (point is GeoPoint) {
        lat = point.latitude;
        lng = point.longitude;
      } else if (point is Map) {
        lat = (point['lat'] as num?)?.toDouble();
        lng = (point['lng'] as num?)?.toDouble();
      }
      place = BookingPlace(
        name: placeRaw['name'] as String? ?? '',
        lat: lat,
        lng: lng,
      );
    } else {
      place = const BookingPlace(name: '');
    }

    BookingCancel? cancel;
    final cancelRaw = data['cancel'];
    if (cancelRaw is Map<String, dynamic>) {
      final at = toDateTime(cancelRaw['at']);
      if (at != null) {
        cancel = BookingCancel(
          by: cancelRaw['by'] as String? ?? 'system',
          reason: cancelRaw['reason'] as String?,
          at: at,
          refundPercent: (cancelRaw['refundPercent'] as num?)?.toInt() ?? 0,
        );
      }
    }

    final statusStr = data['status'] as String? ?? '';
    final status = BookingStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => BookingStatus.draft,
    );

    EscrowStatus? escrowStatus;
    final escrowStr = data['escrowStatus'] as String?;
    if (escrowStr != null) {
      escrowStatus = EscrowStatus.values.cast<EscrowStatus?>().firstWhere(
        (e) =>
            e?.name == escrowStr ||
            (e == EscrowStatus.partiallyRefunded &&
                escrowStr == 'partially_refunded'),
        orElse: () => null,
      );
    }

    final depositVal = data['deposit'];
    final deposit = depositVal is num
        ? depositVal.toInt()
        : depositVal is Map && depositVal['amount'] is num
        ? (depositVal['amount'] as num).toInt()
        : 0;

    final servicePrice = (serviceRaw['price'] as num?)?.toInt() ?? 0;
    final remaining =
        (data['remaining'] as num?)?.toInt() ?? (servicePrice - deposit);

    final createdAt = toDateTime(data['createdAt']) ?? DateTime.now().toUtc();
    final updatedAt = toDateTime(data['updatedAt']) ?? createdAt;

    return Booking(
      id: id,
      customerId: data['customerId'] as String? ?? '',
      photographerId: data['photographerId'] as String? ?? '',
      serviceId: data['serviceId'] as String? ?? '',
      serviceSnapshot: BookingServiceSnapshot(
        name: serviceRaw['name'] as String? ?? '',
        price: servicePrice,
        durationMinutes: (serviceRaw['durationMinutes'] as num?)?.toInt() ?? 60,
      ),
      day: data['day'] as String? ?? data['date'] as String? ?? '',
      start: data['start'] as String? ?? '',
      end: data['end'] as String? ?? '',
      place: place,
      note: data['note'] as String?,
      status: status,
      deposit: deposit,
      remaining: remaining,
      escrowStatus: escrowStatus,
      depositRefunded: (data['depositRefunded'] as num?)?.toInt(),
      depositProvider: data['depositProvider'] as String?,
      depositPaidAt: toDateTime(data['depositPaidAt']),
      depositRefundedAt: toDateTime(data['depositRefundedAt']),
      acceptDeadline: toDateTime(data['acceptDeadline']),
      cancel: cancel,
      completedAt: toDateTime(data['completedAt']),
      reviewedAt: toDateTime(data['reviewedAt']),
      chatId: data['chatId'] as String?,
      version: (data['version'] as num?)?.toInt() ?? 1,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  } catch (_) {
    return null;
  }
}

/// Converts Firestore document snapshot to [BookingContactSnapshot].
BookingContactSnapshot? bookingContactFromFirestore(
  Map<String, dynamic>? data,
) {
  if (data == null) return null;
  DateTime? toDateTime(Object? val) {
    if (val is Timestamp) return val.toDate().toUtc();
    if (val is DateTime) return val.toUtc();
    if (val is String) return DateTime.tryParse(val)?.toUtc();
    return null;
  }

  return BookingContactSnapshot(
    name: data['name'] as String? ?? '',
    phone: data['phone'] as String?,
    allowZalo: data['allowZalo'] as bool? ?? true,
    allowWhatsApp: data['allowWhatsApp'] as bool? ?? false,
    redactedAt: toDateTime(data['redactedAt']),
  );
}

/// Converts Firestore document snapshot to [BookingEventRecord].
BookingEventRecord? bookingEventRecordFromFirestore(
  String id,
  String bookingId,
  Map<String, dynamic>? data,
) {
  if (data == null) return null;

  DateTime? toDateTime(Object? val) {
    if (val is Timestamp) return val.toDate().toUtc();
    if (val is DateTime) return val.toUtc();
    if (val is String) return DateTime.tryParse(val)?.toUtc();
    return null;
  }

  final at = toDateTime(data['at']);
  if (at == null) return null;

  final statusStr = data['status'] as String? ?? '';
  final status = BookingStatus.values.firstWhere(
    (s) => s.name == statusStr,
    orElse: () => BookingStatus.draft,
  );

  return BookingEventRecord(
    id: id,
    bookingId: bookingId,
    status: status,
    at: at,
    actorId: data['actorId'] as String?,
  );
}

