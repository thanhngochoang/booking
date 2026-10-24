// S18 disputes (#142): the dispute as the app reads it (`disputes/{id}`,
// server-written) and the draft S18.01 sends to `openDispute`.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum DisputeSubjectType {
  booking,
  ticket;

  String get code => name;

  /// Unknown → booking (the server only writes the two codes).
  static DisputeSubjectType fromCode(Object? code) =>
      code == 'ticket' ? ticket : booking;
}

/// Where S18.01 was opened from; decides the reasons it offers.
enum DisputeOrigin { booking, deliveryCheck, ticket }

enum DisputeReason {
  noShow('no_show'),
  notAsAgreed('not_as_agreed'),
  photosMissing('photos_missing'),
  notAsSample('not_as_sample'),
  linkBroken('link_broken'),
  eventNotHeld('event_not_held'),
  notAsDescribed('not_as_described'),
  other('other');

  const DisputeReason(this.code);

  final String code;

  /// Unknown or missing → [other].
  static DisputeReason fromCode(Object? code) =>
      values.where((r) => r.code == code).firstOrNull ?? other;

  /// The reasons S18.01 offers, in the mock's chip order (Decision 5).
  static List<DisputeReason> offeredFor(DisputeOrigin origin) =>
      switch (origin) {
        DisputeOrigin.booking => const [
          noShow,
          notAsAgreed,
          photosMissing,
          notAsSample,
          linkBroken,
          other,
        ],
        DisputeOrigin.deliveryCheck => const [
          photosMissing,
          notAsSample,
          linkBroken,
          other,
        ],
        DisputeOrigin.ticket => const [eventNotHeld, notAsDescribed, other],
      };
}

enum DisputeStatus {
  open,
  resolved;

  /// Unknown → open (like the server's mapping).
  static DisputeStatus fromCode(Object? code) =>
      code == 'resolved' ? resolved : open;
}

enum DisputeOutcomeKind {
  release,
  refund,
  split;

  /// Unknown → release (like the server's mapping).
  static DisputeOutcomeKind fromCode(Object? code) =>
      values.where((k) => k.name == code).firstOrNull ?? release;
}

/// The staff decision. Amounts are integer VND.
@immutable
class DisputeOutcome {
  const DisputeOutcome({
    required this.kind,
    required this.refundPercent,
    required this.refundAmount,
    required this.releaseAmount,
    required this.note,
    required this.decidedAt,
  });

  final DisputeOutcomeKind kind;
  final int refundPercent;
  final int refundAmount;
  final int releaseAmount;
  final String note;
  final DateTime decidedAt;
}

@immutable
class Dispute {
  const Dispute({
    required this.id,
    required this.subjectType,
    required this.subjectId,
    this.eventId,
    required this.customerId,
    required this.providerId,
    required this.reason,
    required this.description,
    this.evidencePaths = const [],
    required this.title,
    required this.subtitle,
    this.providerName,
    this.thumbUrl,
    required this.amountHeld,
    required this.status,
    this.outcome,
    required this.threadId,
    required this.createdAt,
    this.resolvedAt,
  });

  /// `disputes/{id}` → dispute. Tolerant like the server's mapping: a missing
  /// field gets its empty value, an unknown code its fallback.
  factory Dispute.fromFirestore(String id, Map<String, dynamic> d) {
    final snap = d['snapshot'] is Map
        ? (d['snapshot'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    return Dispute(
      id: id,
      subjectType: DisputeSubjectType.fromCode(d['subjectType']),
      subjectId: _str(d['subjectId']) ?? '',
      eventId: _str(d['eventId']),
      customerId: _str(d['customerId']) ?? '',
      providerId: _str(d['providerId']) ?? '',
      reason: DisputeReason.fromCode(d['reason']),
      description: _str(d['description']) ?? '',
      evidencePaths: [
        if (d['evidencePaths'] is List)
          for (final p in d['evidencePaths'] as List)
            if (p is String) p,
      ],
      title: _str(snap['title']) ?? '',
      subtitle: _str(snap['subtitle']) ?? '',
      providerName: _str(snap['providerName']),
      thumbUrl: _str(snap['thumbUrl']),
      amountHeld: _int(d['amountHeld']),
      status: DisputeStatus.fromCode(d['status']),
      outcome: _outcome(d['outcome']),
      threadId: _str(d['threadId']) ?? 'dispute_$id',
      createdAt: _time(d['createdAt']) ?? _epoch,
      resolvedAt: _time(d['resolvedAt']),
    );
  }

  final String id;
  final DisputeSubjectType subjectType;

  /// bookingId | registrationId.
  final String subjectId;

  /// Set for a ticket dispute.
  final String? eventId;
  final String customerId;

  /// Photographer uid, event host, or `'platform'` (platform-hosted event).
  final String providerId;
  final DisputeReason reason;
  final String description;

  /// Storage paths (`disputeEvidence/…`), never URLs: resolve them with
  /// `DisputeRepository.evidenceUrl`.
  final List<String> evidencePaths;

  /// Display copy taken when the dispute was opened.
  final String title;
  final String subtitle;
  final String? providerName;
  final String? thumbUrl;

  /// Integer VND frozen at open.
  final int amountHeld;
  final DisputeStatus status;
  final DisputeOutcome? outcome;

  /// `dispute_{id}` in `support_threads`.
  final String threadId;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  bool isCustomer(String uid) => uid == customerId;

  /// A ticket of a platform-hosted event: the released money stays with the
  /// platform (`providerId == 'platform'`), there is no provider party.
  bool get isPlatformHosted => providerId == 'platform';
}

/// `#K7Q2` without the hash: the last 4 characters of the id, upper case
/// (Decision 16, like `bookingCode`).
String disputeCode(String id) =>
    (id.length <= 4 ? id : id.substring(id.length - 4)).toUpperCase();

/// What S18.01 sends to `openDispute`. The client mints [disputeId]
/// (`newUlid()`) before uploading evidence, and re-sending the same id is
/// answered with the same dispute.
@immutable
class DisputeDraft {
  const DisputeDraft({
    required this.disputeId,
    required this.subjectType,
    required this.subjectId,
    this.eventId,
    required this.reason,
    required this.description,
    this.evidencePaths = const [],
  });

  final String disputeId;
  final DisputeSubjectType subjectType;
  final String subjectId;

  /// Required for a ticket.
  final String? eventId;
  final DisputeReason reason;
  final String description;
  final List<String> evidencePaths;
}

/// A refused or failed dispute call: the domain code (`not_eligible`,
/// `deadline_passed`, `conflict`, `permission_denied`, `invalid_argument`,
/// `not_found`) or `'network'`.
class DisputeError implements Exception {
  const DisputeError(this.code);

  final String code;

  @override
  String toString() => 'DisputeError($code)';
}

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

int _int(Object? v) => v is num ? v.toInt() : 0;

DateTime? _time(Object? v) => switch (v) {
  Timestamp() => v.toDate().toUtc(),
  DateTime() => v.toUtc(),
  _ => null,
};

DisputeOutcome? _outcome(Object? v) {
  if (v is! Map) {
    return null;
  }
  return DisputeOutcome(
    kind: DisputeOutcomeKind.fromCode(v['kind']),
    refundPercent: _int(v['refundPercent']),
    refundAmount: _int(v['refundAmount']),
    releaseAmount: _int(v['releaseAmount']),
    note: _str(v['note']) ?? '',
    decidedAt: _time(v['decidedAt']) ?? _epoch,
  );
}
