import 'package:flutter/foundation.dart';

// S27 collaborations (#151): `studio_collaborations/{studioId}_{uid}` and
// `collab_jobs/{bookingId}_{uid}` (the agreed fee and the off-app pay record;
// the customer never reads them, Decision 3). Firestore parsing lives in
// `firestore_collab_repository.dart`.

enum CollabStatus {
  invited('invited'),

  /// Reserved: no callable creates it yet.
  requested('requested'),
  active('active'),
  declined('declined'),
  cancelled('cancelled'),
  expired('expired'),
  ended('ended');

  const CollabStatus(this.code);
  final String code;

  /// Unknown → null: the row is dropped.
  static CollabStatus? fromCode(Object? raw) {
    for (final s in values) {
      if (s.code == raw) return s;
    }
    return null;
  }
}

enum OfferStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined'),
  expired('expired'),
  replaced('replaced'),
  returned('returned'),
  cancelled('cancelled');

  const OfferStatus(this.code);
  final String code;

  /// Unknown → null: the row is dropped.
  static OfferStatus? fromCode(Object? raw) {
    for (final s in values) {
      if (s.code == raw) return s;
    }
    return null;
  }
}

/// The off-app pay record ("Đã trả / Đã nhận", Decision 15).
enum PayStatus {
  none('none'),
  due('due'),
  paidReported('paid_reported'),
  received('received'),
  disputed('disputed');

  const PayStatus(this.code);
  final String code;

  /// Unknown → none, like the server mapping.
  static PayStatus fromCode(Object? raw) {
    for (final s in values) {
      if (s.code == raw) return s;
    }
    return none;
  }
}

/// How the studio says it paid. Not `PayMethod`: `core/payments.dart`
/// already declares that name.
enum CollabPayMethod {
  bank('bank'),
  cash('cash'),
  other('other');

  const CollabPayMethod(this.code);
  final String code;

  static CollabPayMethod? fromCode(Object? raw) {
    for (final m in values) {
      if (m.code == raw) return m;
    }
    return null;
  }
}

/// The latest relationship of a studio and a collaborator.
@immutable
class Collaboration {
  const Collaboration({
    required this.id,
    required this.studioId,
    required this.collaboratorId,
    required this.studioName,
    required this.studioAvatarUrl,
    required this.collaboratorName,
    required this.collaboratorAvatarUrl,
    required this.status,
    required this.defaultFee,
    required this.activeAt,
    required this.expiresAt,
    required this.endedAt,
  });

  final String id;
  final String studioId;
  final String collaboratorId;
  final String studioName;
  final String? studioAvatarUrl;
  final String collaboratorName;
  final String? collaboratorAvatarUrl;
  final CollabStatus status;

  /// Suggested fee per shoot, integer VND; null = none.
  final int? defaultFee;
  final DateTime? activeAt;

  /// When an invite lapses (7 days).
  final DateTime expiresAt;
  final DateTime? endedAt;

  Collaboration copyWith({
    CollabStatus? status,
    int? Function()? defaultFee,
    DateTime? activeAt,
    DateTime? endedAt,
  }) => Collaboration(
    id: id,
    studioId: studioId,
    collaboratorId: collaboratorId,
    studioName: studioName,
    studioAvatarUrl: studioAvatarUrl,
    collaboratorName: collaboratorName,
    collaboratorAvatarUrl: collaboratorAvatarUrl,
    status: status ?? this.status,
    defaultFee: defaultFee == null ? this.defaultFee : defaultFee(),
    activeAt: activeAt ?? this.activeAt,
    expiresAt: expiresAt,
    endedAt: endedAt ?? this.endedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Collaboration &&
      other.id == id &&
      other.status == status &&
      other.defaultFee == defaultFee &&
      other.activeAt == activeAt &&
      other.endedAt == endedAt &&
      other.studioName == studioName &&
      other.collaboratorName == collaboratorName;

  @override
  int get hashCode => Object.hash(id, status, defaultFee, activeAt, endedAt);
}

/// One studio booking offered to a collaborator, with its fee and pay record.
@immutable
class CollabJob {
  const CollabJob({
    required this.id,
    required this.bookingId,
    required this.studioId,
    required this.collaboratorId,
    required this.studioName,
    required this.collaboratorName,
    required this.day,
    required this.start,
    required this.end,
    required this.serviceName,
    required this.placeName,
    required this.agreedFee,
    required this.offerStatus,
    required this.offerExpiresAt,
    required this.acceptedAt,
    required this.payStatus,
    required this.payDueAt,
    required this.paidOn,
    required this.payMethod,
    required this.reportedAt,
    required this.updatedAt,
  });

  final String id;
  final String bookingId;
  final String studioId;
  final String collaboratorId;
  final String studioName;
  final String collaboratorName;

  /// Vietnam calendar day `yyyy-MM-dd` and `HH:mm` times of the shoot.
  final String day;
  final String start;
  final String end;
  final String serviceName;
  final String placeName;

  /// Integer VND.
  final int agreedFee;
  final OfferStatus offerStatus;
  final DateTime offerExpiresAt;
  final DateTime? acceptedAt;
  final PayStatus payStatus;
  final DateTime? payDueAt;

  /// Vietnam calendar day `yyyy-MM-dd` the studio says it paid.
  final String? paidOn;
  final CollabPayMethod? payMethod;
  final DateTime? reportedAt;
  final DateTime updatedAt;

  CollabJob copyWith({
    OfferStatus? offerStatus,
    DateTime? acceptedAt,
    PayStatus? payStatus,
    String? paidOn,
    CollabPayMethod? payMethod,
    DateTime? reportedAt,
    DateTime? updatedAt,
  }) => CollabJob(
    id: id,
    bookingId: bookingId,
    studioId: studioId,
    collaboratorId: collaboratorId,
    studioName: studioName,
    collaboratorName: collaboratorName,
    day: day,
    start: start,
    end: end,
    serviceName: serviceName,
    placeName: placeName,
    agreedFee: agreedFee,
    offerStatus: offerStatus ?? this.offerStatus,
    offerExpiresAt: offerExpiresAt,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    payStatus: payStatus ?? this.payStatus,
    payDueAt: payDueAt,
    paidOn: paidOn ?? this.paidOn,
    payMethod: payMethod ?? this.payMethod,
    reportedAt: reportedAt ?? this.reportedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is CollabJob &&
      other.id == id &&
      other.offerStatus == offerStatus &&
      other.payStatus == payStatus &&
      other.agreedFee == agreedFee &&
      other.paidOn == paidOn &&
      other.payMethod == payMethod &&
      other.payDueAt == payDueAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, offerStatus, payStatus, agreedFee, paidOn, updatedAt);
}
