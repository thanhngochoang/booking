// lib/data/payments/payment_group.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_group.freezed.dart';

/// What a line of a group payment pays for (Decision 6, `LineKind`).
enum PaymentLineKind {
  booking('booking'),
  entryTicket('entry_ticket'),
  eventTicket('event_ticket'),
  venueFee('venue_fee');

  const PaymentLineKind(this.code);
  final String code;

  static PaymentLineKind? fromCode(Object? code) {
    for (final k in values) {
      if (k.code == code) return k;
    }
    return null;
  }
}

/// Mirrors the group payment: `created` (waiting), `paid`, `expired`.
enum PaymentGroupStatus { created, paid, expired }

@freezed
abstract class PaymentGroupLine with _$PaymentGroupLine {
  const factory PaymentGroupLine({
    required String paymentId,
    required PaymentLineKind kind,

    /// `booking` or `event_registration`.
    required String subjectType,
    required String subjectId,

    /// Who receives this line (the photographer, the venue's organizer, …).
    required String payeeId,

    /// Integer VND.
    required int amount,
  }) = _PaymentGroupLine;
}

/// `payment_groups/{id}` (id = the group payment id; readable by the payer
/// only): the lines S04.03-entry and S05.02 show under one VietQR.
@freezed
abstract class PaymentGroup with _$PaymentGroup {
  const PaymentGroup._();

  const factory PaymentGroup({
    required String id,
    required String payerId,
    required List<PaymentGroupLine> lines,
    required int total,
    required PaymentGroupStatus status,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _PaymentGroup;

  /// Σ of the lines of [kind] (0 when there is none).
  int amountOf(PaymentLineKind kind) =>
      lines.where((l) => l.kind == kind).fold(0, (n, l) => n + l.amount);

  /// Reads the stored document; lines of an unknown kind are dropped (as the
  /// server's own reader does). Null when the document is missing.
  static PaymentGroup? fromDoc(String id, Map<String, dynamic>? d) {
    if (d == null) return null;
    DateTime? date(Object? v) {
      if (v is Timestamp) return v.toDate().toUtc();
      if (v is DateTime) return v.toUtc();
      if (v is String) return DateTime.tryParse(v)?.toUtc();
      return null;
    }

    final raw = d['lines'];
    final lines = <PaymentGroupLine>[];
    if (raw is List) {
      for (final l in raw) {
        if (l is! Map) continue;
        final kind = PaymentLineKind.fromCode(l['kind']);
        final amount = l['amount'];
        if (kind == null || amount is! num) continue;
        String s(Object? v) => v is String ? v : '';
        lines.add(
          PaymentGroupLine(
            paymentId: s(l['paymentId']),
            kind: kind,
            subjectType: s(l['subjectType']),
            subjectId: s(l['subjectId']),
            payeeId: s(l['payeeId']),
            amount: amount.toInt(),
          ),
        );
      }
    }
    return PaymentGroup(
      id: id,
      payerId: d['payerId'] is String ? d['payerId'] as String : '',
      lines: lines,
      total: d['total'] is num ? (d['total'] as num).toInt() : 0,
      status: switch (d['status']) {
        'paid' => PaymentGroupStatus.paid,
        'expired' => PaymentGroupStatus.expired,
        _ => PaymentGroupStatus.created,
      },
      expiresAt: date(d['expiresAt']),
      createdAt: date(d['createdAt']),
      updatedAt: date(d['updatedAt']),
    );
  }
}

abstract class PaymentGroupRepository {
  /// Null when missing or not mine (the rules refuse it).
  Stream<PaymentGroup?> watch(String groupId);
}

class FirestorePaymentGroupRepository implements PaymentGroupRepository {
  FirestorePaymentGroupRepository({FirebaseFirestore? db}) : _override = db;

  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  @override
  Stream<PaymentGroup?> watch(String groupId) {
    if (groupId.isEmpty || groupId.contains('/')) return Stream.value(null);
    return _db
        .collection('payment_groups')
        .doc(groupId)
        .snapshots()
        .map((s) => PaymentGroup.fromDoc(s.id, s.data()))
        .transform(
          StreamTransformer<PaymentGroup?, PaymentGroup?>.fromHandlers(
            handleError: (e, st, sink) {
              if (e is FirebaseException && e.code == 'permission-denied') {
                sink.add(null);
              } else {
                sink.addError(e, st);
              }
            },
          ),
        );
  }
}

/// In-memory groups for tests and previews.
class FakePaymentGroupRepository implements PaymentGroupRepository {
  final Map<String, PaymentGroup> groups = {};
  final _changes = StreamController<void>.broadcast();

  void put(PaymentGroup g) {
    groups[g.id] = g;
    _changes.add(null);
  }

  @override
  Stream<PaymentGroup?> watch(String groupId) async* {
    yield groups[groupId];
    yield* _changes.stream.map((_) => groups[groupId]);
  }
}

final paymentGroupRepositoryProvider = Provider<PaymentGroupRepository>(
  (ref) => FirestorePaymentGroupRepository(),
);

/// The lines of a booking's group payment (`Booking.groupId`).
final paymentGroupProvider = StreamProvider.autoDispose
    .family<PaymentGroup?, String>(
      (ref, groupId) =>
          ref.watch(paymentGroupRepositoryProvider).watch(groupId),
    );
