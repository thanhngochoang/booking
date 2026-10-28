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

_BookingAddonLine _$BookingAddonLineFromJson(Map<String, dynamic> json) =>
    _BookingAddonLine(
      addonId: json['addonId'] as String,
      kind: $enumDecode(_$AddonKindEnumMap, json['kind']),
      name: json['name'] as String,
      unit: $enumDecode(_$AddonUnitEnumMap, json['unit']),
      unitPrice: (json['unitPrice'] as num).toInt(),
      qty: (json['qty'] as num).toInt(),
      amount: (json['amount'] as num).toInt(),
    );

Map<String, dynamic> _$BookingAddonLineToJson(_BookingAddonLine instance) =>
    <String, dynamic>{
      'addonId': instance.addonId,
      'kind': _$AddonKindEnumMap[instance.kind]!,
      'name': instance.name,
      'unit': _$AddonUnitEnumMap[instance.unit]!,
      'unitPrice': instance.unitPrice,
      'qty': instance.qty,
      'amount': instance.amount,
    };

const _$AddonKindEnumMap = {
  AddonKind.makeup: 'makeup',
  AddonKind.retouch: 'retouch',
  AddonKind.transport: 'transport',
  AddonKind.outfit: 'outfit',
  AddonKind.other: 'other',
};

const _$AddonUnitEnumMap = {
  AddonUnit.perBooking: 'per_booking',
  AddonUnit.perPerson: 'per_person',
  AddonUnit.perItem: 'per_item',
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
  BookingStatus.shot: 'shot',
  BookingStatus.delivered: 'delivered',
  BookingStatus.revisionRequested: 'revisionRequested',
  BookingStatus.approved: 'approved',
  BookingStatus.completed: 'completed',
  BookingStatus.reviewed: 'reviewed',
};

_PhotoNote _$PhotoNoteFromJson(Map<String, dynamic> json) => _PhotoNote(
  sampleIndex: (json['sampleIndex'] as num).toInt(),
  note: json['note'] as String,
);

Map<String, dynamic> _$PhotoNoteToJson(_PhotoNote instance) =>
    <String, dynamic>{
      'sampleIndex': instance.sampleIndex,
      'note': instance.note,
    };

_ExtraRound _$ExtraRoundFromJson(Map<String, dynamic> json) => _ExtraRound(
  status: json['status'] as String,
  at: DateTime.parse(json['at'] as String),
  note: json['note'] as String?,
  photoNotes:
      (json['photoNotes'] as List<dynamic>?)
          ?.map((e) => PhotoNote.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <PhotoNote>[],
);

Map<String, dynamic> _$ExtraRoundToJson(_ExtraRound instance) =>
    <String, dynamic>{
      'status': instance.status,
      'at': instance.at.toIso8601String(),
      'note': instance.note,
      'photoNotes': instance.photoNotes,
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
  addons:
      (json['addons'] as List<dynamic>?)
          ?.map((e) => BookingAddonLine.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <BookingAddonLine>[],
  pickup: json['pickup'] == null
      ? null
      : BookingPlace.fromJson(json['pickup'] as Map<String, dynamic>),
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
  shotAt: json['shotAt'] == null
      ? null
      : DateTime.parse(json['shotAt'] as String),
  deliveredAt: json['deliveredAt'] == null
      ? null
      : DateTime.parse(json['deliveredAt'] as String),
  approvedAt: json['approvedAt'] == null
      ? null
      : DateTime.parse(json['approvedAt'] as String),
  checkUntil: json['checkUntil'] == null
      ? null
      : DateTime.parse(json['checkUntil'] as String),
  autoApproveAt: json['autoApproveAt'] == null
      ? null
      : DateTime.parse(json['autoApproveAt'] as String),
  autoApproveNoticeAt: json['autoApproveNoticeAt'] == null
      ? null
      : DateTime.parse(json['autoApproveNoticeAt'] as String),
  samplesPurgeAfter: json['samplesPurgeAfter'] == null
      ? null
      : DateTime.parse(json['samplesPurgeAfter'] as String),
  deliveryRound: (json['deliveryRound'] as num?)?.toInt() ?? 0,
  revisionsIncluded: (json['revisionsIncluded'] as num?)?.toInt() ?? 1,
  revisionsUsed: (json['revisionsUsed'] as num?)?.toInt() ?? 0,
  revisionsGranted: (json['revisionsGranted'] as num?)?.toInt() ?? 0,
  extraRound: json['extraRound'] == null
      ? null
      : ExtraRound.fromJson(json['extraRound'] as Map<String, dynamic>),
  samplesPurged: json['samplesPurged'] as bool? ?? false,
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  reviewedAt: json['reviewedAt'] == null
      ? null
      : DateTime.parse(json['reviewedAt'] as String),
  chatId: json['chatId'] as String?,
  spotId: json['spotId'] as String?,
  spotScheduleId: json['spotScheduleId'] as String?,
  slotOfferId: json['slotOfferId'] as String?,
  source: json['source'] as String?,
  jobId: json['jobId'] as String?,
  quoteId: json['quoteId'] as String?,
  disputeId: json['disputeId'] as String?,
  studio: json['studio'] == null
      ? null
      : StudioBookingInfo.fromJson(json['studio'] as Map<String, dynamic>),
  refundAccountNeeded: json['refundAccountNeeded'] as bool? ?? false,
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
  'addons': instance.addons,
  'pickup': instance.pickup,
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
  'shotAt': instance.shotAt?.toIso8601String(),
  'deliveredAt': instance.deliveredAt?.toIso8601String(),
  'approvedAt': instance.approvedAt?.toIso8601String(),
  'checkUntil': instance.checkUntil?.toIso8601String(),
  'autoApproveAt': instance.autoApproveAt?.toIso8601String(),
  'autoApproveNoticeAt': instance.autoApproveNoticeAt?.toIso8601String(),
  'samplesPurgeAfter': instance.samplesPurgeAfter?.toIso8601String(),
  'deliveryRound': instance.deliveryRound,
  'revisionsIncluded': instance.revisionsIncluded,
  'revisionsUsed': instance.revisionsUsed,
  'revisionsGranted': instance.revisionsGranted,
  'extraRound': instance.extraRound,
  'samplesPurged': instance.samplesPurged,
  'completedAt': instance.completedAt?.toIso8601String(),
  'reviewedAt': instance.reviewedAt?.toIso8601String(),
  'chatId': instance.chatId,
  'spotId': instance.spotId,
  'spotScheduleId': instance.spotScheduleId,
  'slotOfferId': instance.slotOfferId,
  'source': instance.source,
  'jobId': instance.jobId,
  'quoteId': instance.quoteId,
  'disputeId': instance.disputeId,
  'studio': instance.studio,
  'refundAccountNeeded': instance.refundAccountNeeded,
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
