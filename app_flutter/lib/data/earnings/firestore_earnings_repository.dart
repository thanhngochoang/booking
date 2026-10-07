import 'dart:async';
import 'dart:io' show SocketException;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/earnings/earnings.dart';
import 'package:photobooking/data/earnings/earnings_repository.dart';

bool _validId(String id) => id.isNotEmpty && !id.contains('/');

int _int(Object? v) => v is num ? v.toInt() : 0;

String _str(Object? v) => v is String ? v : '';

DateTime? _time(Object? v) => v is Timestamp ? v.toDate().toUtc() : null;

/// Parses `earnings/{uid}`; a missing document is all zero.
EarningsSummary earningsSummaryFrom(
  Map<String, dynamic>? d, {
  bool fromCache = false,
}) {
  if (d == null) return EarningsSummary(fromCache: fromCache);
  final last = d['lastPayout'];
  return EarningsSummary(
    heldVnd: _int(d['heldAmount']),
    soonVnd: _int(d['soonAmount']),
    receivedVnd: _int(d['receivedAmount']),
    lastPayoutFailed: last is Map && last['status'] == 'failed',
    lastPayoutAt: last is Map ? _time(last['at']) : null,
    fromCache: fromCache,
  );
}

/// Parses an `earnings/{uid}/items/{id}` doc; null for an unknown state code.
EarningItem? earningItemFrom(String id, Map<String, dynamic> d) {
  final state = EarningState.fromCode(d['state']);
  if (state == null) return null;
  final reason = d['holdReason'];
  return EarningItem(
    id: id,
    subjectType: _str(d['subjectType']),
    subjectId: _str(d['subjectId']),
    counterpartName: _str(d['counterpartName']),
    subjectLabel: _str(d['subjectLabel']),
    day: _str(d['day']),
    amountVnd: _int(d['amount']),
    state: state,
    holdReason: reason is String && reason.isNotEmpty ? reason : null,
    paidOutAt: _time(d['paidOutAt']),
  );
}

/// Parses `payoutAccounts/{uid}`. Reads only the masked fields.
PayoutAccountView? payoutAccountViewFrom(Map<String, dynamic>? d) {
  if (d == null) return null;
  final id = d['accountId'];
  final bank = d['bankCode'];
  final last4 = d['accountLast4'];
  final holder = d['holderName'];
  if (id is! String ||
      bank is! String ||
      last4 is! String ||
      holder is! String) {
    return null;
  }
  return PayoutAccountView(
    accountId: id,
    bankCode: bank,
    accountLast4: last4,
    holderName: holder,
    updatedAt:
        _time(d['updatedAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

/// Maps a callable failure to a [PayoutAccountError] code.
String payoutAccountErrorCodeOf(Object error) {
  if (error is SocketException) return 'network';
  if (error is FirebaseFunctionsException) {
    if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
      return 'network';
    }
    final details = error.details;
    final raw = details is Map && details['code'] is String
        ? details['code'] as String
        : (error.message ?? error.code);
    return switch (raw) {
      'reauth_required' => 'reauth_required',
      'conflict' => 'conflict',
      'invalid_argument' || 'invalid-argument' => 'invalid_argument',
      'permission_denied' || 'permission-denied' => 'permission_denied',
      'unavailable' || 'deadline-exceeded' || 'network' => 'network',
      _ => 'unknown',
    };
  }
  return 'unknown';
}

/// Reads the owner-only projection (`earnings`, `payoutAccounts`); the account
/// is saved through the `savePayoutAccount` callable.
class FirestoreEarningsRepository implements EarningsRepository {
  FirestoreEarningsRepository({
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
  }) : _override = db,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  final FirebaseFirestore? _override;
  final FirebaseFunctions _functions;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  @override
  Stream<EarningsSummary> watchSummary(String uid) {
    if (!_validId(uid)) return Stream.value(const EarningsSummary());
    return _db
        .collection('earnings')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .map(
          (s) =>
              earningsSummaryFrom(s.data(), fromCache: s.metadata.isFromCache),
        );
  }

  @override
  Stream<List<EarningItem>> watchItems(String uid, {required int limit}) {
    if (!_validId(uid)) return Stream.value(const <EarningItem>[]);
    return _db
        .collection('earnings')
        .doc(uid)
        .collection('items')
        .orderBy('day', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => [
            for (final d in snap.docs) ?earningItemFrom(d.id, d.data()),
          ],
        );
  }

  @override
  Stream<PayoutAccountView?> watchAccount(String uid) {
    if (!_validId(uid)) return Stream.value(null);
    return _db
        .collection('payoutAccounts')
        .doc(uid)
        .snapshots()
        .map((s) => payoutAccountViewFrom(s.data()));
  }

  @override
  Future<({String accountId, String accountLast4})> saveAccount({
    required String bankCode,
    required String accountNumber,
    required String holderName,
  }) async {
    try {
      final r = await _functions
          .httpsCallable(
            'savePayoutAccount',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
          )
          .call<Object?>({
            'bankCode': bankCode,
            'accountNumber': accountNumber,
            'holderName': holderName,
          });
      final data = r.data;
      if (data is Map &&
          data['accountId'] is String &&
          data['accountLast4'] is String) {
        return (
          accountId: data['accountId'] as String,
          accountLast4: data['accountLast4'] as String,
        );
      }
      throw const PayoutAccountError('unknown');
    } on PayoutAccountError {
      rethrow;
    } catch (e) {
      // Only the code leaves this method: never the arguments or the message.
      throw PayoutAccountError(payoutAccountErrorCodeOf(e));
    }
  }
}
