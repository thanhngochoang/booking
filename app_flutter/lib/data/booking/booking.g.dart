// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BookingServiceSnapshot _$BookingServiceSnapshotFromJson(
  Map<String, dynamic> json,
) => _BookingServiceSnapshot(
  name: json['name'] as String,
  price: (json['price'] as num).toInt(),
  durationMinutes: (json['durationMinutes'] as num).toInt(),
);

Map<String, dynamic> _$BookingServiceSnapshotToJson(
  _BookingServiceSnapshot instance,
) => <String, dynamic>{
  'name': instance.name,
  'price': instance.price,
  'durationMinutes': instance.durationMinutes,
};

_BookingPlace _$BookingPlaceFromJson(Map<String, dynamic> json) =>
    _BookingPlace(
      name: json['name'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$BookingPlaceToJson(_BookingPlace instance) =>
    <String, dynamic>{
      'name': instance.name,
      'lat': instance.lat,
      'lng': instance.lng,
    };

_BookingCancel _$BookingCancelFromJson(Map<String, dynamic> json) =>
    _BookingCancel(
      by: json['by'] as String,
      reason: json['reason'] as String?,
      at: DateTime.parse(json['at'] as String),
      refundPercent: (json['refundPercent'] as num).toInt(),
    );

Map<String, dynamic> _$BookingCancelToJson(_BookingCancel instance) =>
    <String, dynamic>{
      'by': instance.by,
      'reason': instance.reason,
      'at': instance.at.toIso8601String(),
      'refundPercent': instance.refundPercent,
    };

_BookingContactSnapshot _$BookingContactSnapshotFromJson(
  Map<String, dynamic> json,
) => _BookingContactSnapshot(
  name: json['name'] as String,
  phone: json['phone'] as String?,
  allowZalo: json['allowZalo'] as bool? ?? true,
  allowWhatsApp: json['allowWhatsApp'] as bool? ?? false,
  redactedAt: json['redactedAt'] == null
      ? null
      : DateTime.parse(json['redactedAt'] as String),
);

Map<String, dynamic> _$BookingContactSnapshotToJson(
  _BookingContactSnapshot instance,
) => <String, dynamic>{
  'name': instance.name,
  'phone': instance.phone,
  'allowZalo': instance.allowZalo,
  'allowWhatsApp': instance.allowWhatsApp,
  'redactedAt': instance.redactedAt?.toIso8601String(),
};

_BookingEventRecord _$BookingEventRecordFromJson(Map<String, dynamic> json) =>
    _BookingEventRecord(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      status: $enumDecode(_$BookingStatusEnumMap, json['status']),
      at: DateTime.parse(json['at'] as String),
      actorId: json['actorId'] as String?,
    );

Map<String, dynamic> _$BookingEventRecordToJson(_BookingEventRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'bookingId': instance.bookingId,
      'status': _$BookingStatusEnumMap[instance.status]!,
      'at': instance.at.toIso8601String(),
      'actorId': instance.actorId,
    };

const _$BookingStatusEnumMap = {
  BookingStatus.draft: 'draft',
  BookingStatus.requested: 'requested',
  BookingStatus.accepted: 'accepted',
  BookingStatus.declined: 'declined',
  BookingStatus.expired: 'expired',
  BookingStatus.cancelled: 'cancelled',
  BookingStatus.upcoming: 'upcoming',
  BookingStatus.completed: 'completed',
  BookingStatus.reviewed: 'reviewed',
};

_Booking _$BookingFromJson(Map<String, dynamic> json) => _Booking(
  id: json['id'] as String,
  customerId: json['customerId'] as String,
  photographerId: json['photographerId'] as String,
  serviceId: json['serviceId'] as String,
  serviceSnapshot: BookingServiceSnapshot.fromJson(
    json['serviceSnapshot'] as Map<String, dynamic>,
  ),
  day: json['day'] as String,
  start: json['start'] as String,
  end: json['end'] as String,
  place: BookingPlace.fromJson(json['place'] as Map<String, dynamic>),
  note: json['note'] as String?,
  status: $enumDecode(_$BookingStatusEnumMap, json['status']),
  deposit: (json['deposit'] as num).toInt(),
  remaining: (json['remaining'] as num).toInt(),
  escrowStatus: $enumDecodeNullable(
    _$EscrowStatusEnumMap,
    json['escrowStatus'],
  ),
  depositRefunded: (json['depositRefunded'] as num?)?.toInt(),
  depositProvider: json['depositProvider'] as String?,
  depositPaidAt: json['depositPaidAt'] == null
      ? null
      : DateTime.parse(json['depositPaidAt'] as String),
  depositRefundedAt: json['depositRefundedAt'] == null
      ? null
      : DateTime.parse(json['depositRefundedAt'] as String),
  acceptDeadline: json['acceptDeadline'] == null
      ? null
      : DateTime.parse(json['acceptDeadline'] as String),
  cancel: json['cancel'] == null
      ? null
      : BookingCancel.fromJson(json['cancel'] as Map<String, dynamic>),
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  reviewedAt: json['reviewedAt'] == null
      ? null
      : DateTime.parse(json['reviewedAt'] as String),
  chatId: json['chatId'] as String?,
  version: (json['version'] as num?)?.toInt() ?? 1,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$BookingToJson(_Booking instance) => <String, dynamic>{
  'id': instance.id,
  'customerId': instance.customerId,
  'photographerId': instance.photographerId,
  'serviceId': instance.serviceId,
  'serviceSnapshot': instance.serviceSnapshot,
  'day': instance.day,
  'start': instance.start,
  'end': instance.end,
  'place': instance.place,
  'note': instance.note,
  'status': _$BookingStatusEnumMap[instance.status]!,
  'deposit': instance.deposit,
  'remaining': instance.remaining,
  'escrowStatus': _$EscrowStatusEnumMap[instance.escrowStatus],
  'depositRefunded': instance.depositRefunded,
  'depositProvider': instance.depositProvider,
  'depositPaidAt': instance.depositPaidAt?.toIso8601String(),
  'depositRefundedAt': instance.depositRefundedAt?.toIso8601String(),
  'acceptDeadline': instance.acceptDeadline?.toIso8601String(),
  'cancel': instance.cancel,
  'completedAt': instance.completedAt?.toIso8601String(),
  'reviewedAt': instance.reviewedAt?.toIso8601String(),
  'chatId': instance.chatId,
  'version': instance.version,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

const _$EscrowStatusEnumMap = {
  EscrowStatus.held: 'held',
  EscrowStatus.released: 'released',
  EscrowStatus.disputed: 'disputed',
  EscrowStatus.refunded: 'refunded',
  EscrowStatus.partiallyRefunded: 'partially_refunded',
};
