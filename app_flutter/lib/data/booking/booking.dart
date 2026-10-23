import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/booking/booking_checkout.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/booking/studio_booking.dart';

export 'package:photobooking/data/booking/studio_booking.dart';

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

/// One add-on line of a booking: the snapshot taken when it was created
/// (`amount = unitPrice × qty`).
@freezed
abstract class BookingAddonLine with _$BookingAddonLine {
  const factory BookingAddonLine({
    required String addonId,
    required AddonKind kind,
    required String name,
    required AddonUnit unit,
    required int unitPrice,
    required int qty,
    required int amount,
  }) = _BookingAddonLine;

  factory BookingAddonLine.fromJson(Map<String, dynamic> json) =>
      _$BookingAddonLineFromJson(json);
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
abstract class PhotoNote with _$PhotoNote {
  const factory PhotoNote({
    required int sampleIndex,
    required String note,
  }) = _PhotoNote;

  factory PhotoNote.fromJson(Map<String, dynamic> json) =>
      _$PhotoNoteFromJson(json);
}

@freezed
abstract class ExtraRound with _$ExtraRound {
  const factory ExtraRound({
    required String status,
    required DateTime at,
    String? note,
    @Default(<PhotoNote>[]) List<PhotoNote> photoNotes,
  }) = _ExtraRound;

  factory ExtraRound.fromJson(Map<String, dynamic> json) =>
      _$ExtraRoundFromJson(json);
}

@freezed
abstract class Booking with _$Booking {
  const Booking._();

  /// What the customer pays: package price + Σ add-on amounts.
  int get totalVnd =>
      addons.fold(serviceSnapshot.price, (total, l) => total + l.amount);

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

    /// Add-on snapshot lines (S04.03, S05.02); empty on old bookings.
    @Default(<BookingAddonLine>[]) List<BookingAddonLine> addons,

    /// Pick-up address, only with a `transport` add-on; two parties read it.
    BookingPlace? pickup,
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
    DateTime? shotAt,
    DateTime? deliveredAt,
    DateTime? approvedAt,
    DateTime? checkUntil,
    DateTime? autoApproveAt,
    DateTime? autoApproveNoticeAt,
    DateTime? samplesPurgeAfter,
    @Default(0) int deliveryRound,
    @Default(1) int revisionsIncluded,
    @Default(0) int revisionsUsed,
    @Default(0) int revisionsGranted,
    ExtraRound? extraRound,
    @Default(false) bool samplesPurged,
    DateTime? completedAt,
    DateTime? reviewedAt,
    String? chatId,
    String? spotId,
    String? spotScheduleId,
    String? slotOfferId,
    String? source,
    String? jobId,
    String? quoteId,

    /// The studio part (#136); null for an individual booking.
    StudioBookingInfo? studio,

    /// What S04.04 pays: mirror of `bookings/{id}.checkout`, set while a draft
    /// waits for its payment. Not part of the JSON form.
    @JsonKey(includeFromJson: false, includeToJson: false)
    BookingCheckout? checkout,
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

    final status =
        bookingStatusFromCode(data['status'] as String?) ?? BookingStatus.draft;

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
    final addons = _addonLinesFrom(data['addons']);
    final total = addons.fold(servicePrice, (total, l) => total + l.amount);
    final remaining = (data['remaining'] as num?)?.toInt() ?? (total - deposit);

    final createdAt = toDateTime(data['createdAt']) ?? DateTime.now().toUtc();
    final updatedAt = toDateTime(data['updatedAt']) ?? createdAt;

    ExtraRound? extraRound;
    final extraRaw = data['extraRound'];
    if (extraRaw is Map<String, dynamic>) {
      final at = toDateTime(extraRaw['at']);
      if (at != null) {
        final notesRaw = extraRaw['photoNotes'];
        final photoNotes = <PhotoNote>[];
        if (notesRaw is List) {
          for (final n in notesRaw) {
            if (n is Map && n['sampleIndex'] is num && n['note'] is String) {
              photoNotes.add(
                PhotoNote(
                  sampleIndex: (n['sampleIndex'] as num).toInt(),
                  note: n['note'] as String,
                ),
              );
            }
          }
        }
        extraRound = ExtraRound(
          status: extraRaw['status'] as String? ?? 'pending',
          at: at,
          note: extraRaw['note'] as String?,
          photoNotes: photoNotes,
        );
      }
    }

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
      addons: addons,
      pickup: _placeFrom(data['pickup']),
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
      shotAt: toDateTime(data['shotAt']),
      deliveredAt: toDateTime(data['deliveredAt']),
      approvedAt: toDateTime(data['approvedAt']),
      checkUntil: toDateTime(data['checkUntil']),
      autoApproveAt: toDateTime(data['autoApproveAt']),
      autoApproveNoticeAt: toDateTime(data['autoApproveNoticeAt']),
      samplesPurgeAfter: toDateTime(data['samplesPurgeAfter']),
      deliveryRound: (data['deliveryRound'] as num?)?.toInt() ?? 0,
      revisionsIncluded: (data['revisionsIncluded'] as num?)?.toInt() ?? 1,
      revisionsUsed: (data['revisionsUsed'] as num?)?.toInt() ?? 0,
      revisionsGranted: (data['revisionsGranted'] as num?)?.toInt() ?? 0,
      extraRound: extraRound,
      samplesPurged: data['samplesPurged'] as bool? ?? false,
      completedAt: toDateTime(data['completedAt']),
      reviewedAt: toDateTime(data['reviewedAt']),
      chatId: data['chatId'] as String?,
      studio: studioBookingInfoFrom(data),
      spotId: data['spotId'] as String?,
      spotScheduleId: data['spotScheduleId'] as String?,
      slotOfferId: data['slotOfferId'] as String?,
      source: data['source'] as String?,
      jobId: data['jobId'] as String?,
      quoteId: data['quoteId'] as String?,
      checkout: bookingCheckoutFrom(data['checkout']),
      version: (data['version'] as num?)?.toInt() ?? 1,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  } catch (_) {
    return null;
  }
}

List<BookingAddonLine> _addonLinesFrom(Object? raw) {
  if (raw is! List) return const [];
  final lines = <BookingAddonLine>[];
  for (final l in raw) {
    if (l is! Map) continue;
    final kind = AddonKind.fromCode(l['kind']);
    final unit = AddonUnit.fromCode(l['unit']);
    final addonId = l['addonId'];
    final name = l['name'];
    final unitPrice = l['unitPrice'];
    final qty = l['qty'];
    final amount = l['amount'];
    if (kind == null ||
        unit == null ||
        addonId is! String ||
        name is! String ||
        unitPrice is! num ||
        qty is! num ||
        amount is! num) {
      continue;
    }
    lines.add(
      BookingAddonLine(
        addonId: addonId,
        kind: kind,
        name: name,
        unit: unit,
        unitPrice: unitPrice.toInt(),
        qty: qty.toInt(),
        amount: amount.toInt(),
      ),
    );
  }
  return lines;
}

BookingPlace? _placeFrom(Object? raw) {
  if (raw is! Map || raw['name'] is! String) return null;
  double? lat;
  double? lng;
  final point = raw['point'];
  if (point is GeoPoint) {
    lat = point.latitude;
    lng = point.longitude;
  } else if (point is Map) {
    lat = (point['lat'] as num?)?.toDouble();
    lng = (point['lng'] as num?)?.toDouble();
  }
  return BookingPlace(name: raw['name'] as String, lat: lat, lng: lng);
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

  final status =
      bookingStatusFromCode(data['status'] as String?) ?? BookingStatus.draft;

  return BookingEventRecord(
    id: id,
    bookingId: bookingId,
    status: status,
    at: at,
    actorId: data['actorId'] as String?,
  );
}
