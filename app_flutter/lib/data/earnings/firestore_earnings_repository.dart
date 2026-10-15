import 'dart:async';
import 'dart:io' show SocketException;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/earnings/earnings.dart';
import 'package:photobooking/data/earnings/earnings_repository.dart';

bool _validId(String id) => id.isNotEmpty && !id.contains('/');

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

int? _intOrNull(Object? v) => v is num ? v.toInt() : null;

String? _strOrNull(Object? v) => v is String ? v : null;

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
/// A row written before the breakdown existed reads fee 0, tax 0,
/// net = amount, estimated, no milestones.
EarningItem? earningItemFrom(String id, Map<String, dynamic> d) {
  final state = EarningState.fromCode(d['state']);
  if (state == null) return null;
  final reason = d['holdReason'];
  final amount = _int(d['amount']);
  return EarningItem(
    id: id,
    subjectType: _str(d['subjectType']),
    subjectId: _str(d['subjectId']),
    counterpartName: _str(d['counterpartName']),
    subjectLabel: _str(d['subjectLabel']),
    day: _str(d['day']),
    amountVnd: amount,
    state: state,
    holdReason: reason is String && reason.isNotEmpty ? reason : null,
    paidOutAt: _time(d['paidOutAt']),
    feeVnd: _int(d['platformFee']),
    taxVnd: _int(d['taxWithheld']),
    netVnd: _int(d['netAmount'], amount),
    feeRateBp: _int(d['feeRateBp']),
    taxRateBp: _int(d['taxRateBp']),
    estimated: d['estimated'] != false,
    milestonesDone: _intOrNull(d['milestonesDone']),
    milestonesTotal: _intOrNull(d['milestonesTotal']),
  );
}

/// Parses `payoutAccounts/{uid}`. Reads only the masked fields. A view written
/// before the name check reads `matched`, active from `updatedAt`.
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
  final updatedAt =
      _time(d['updatedAt']) ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  return PayoutAccountView(
    accountId: id,
    bankCode: bank,
    accountLast4: last4,
    holderName: holder,
    updatedAt: updatedAt,
    activeFrom: _time(d['activeFrom']) ?? updatedAt,
    nameStatus: PayoutNameStatus.fromCode(d['nameStatus']),
  );
}

/// Refusal codes of the payout account callables the app tells apart.
const _payoutAccountCodes = {
  'name_mismatch',
  'not_found',
  'not_eligible',
  'otp_required',
  'otp_invalid',
  'otp_expired',
  'limit_exceeded',
  'phone_required',
  'reauth_required',
  'conflict',
  'invalid_argument',
  'permission_denied',
};

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
    if (_payoutAccountCodes.contains(raw)) return raw;
    return switch (raw) {
      'invalid-argument' => 'invalid_argument',
      'permission-denied' || 'unauthenticated' => 'permission_denied',
      'not-found' => 'not_found',
      'resource-exhausted' => 'limit_exceeded',
      'aborted' => 'conflict',
      'unavailable' || 'deadline-exceeded' || 'network' => 'network',
      _ => 'unknown',
    };
  }
  return 'unknown';
}

/// Reads the owner-only projection (`earnings`, `payoutAccounts`); the account
/// is looked up, confirmed by OTP and saved through the callables
/// `lookupPayoutAccountName`, `requestPayoutOtp` and `savePayoutAccount`.
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

  /// Calls [name]; any failure leaves as a [PayoutAccountError] carrying only
  /// the code, never the arguments or the message.
  Future<Map<Object?, Object?>> _call(
    String name,
    Map<String, Object> payload,
  ) async {
    try {
      final r = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
          )
          .call<Object?>(payload);
      final data = r.data;
      if (data is Map) return data;
      throw const PayoutAccountError('unknown');
    } on PayoutAccountError {
      rethrow;
    } catch (e) {
      throw PayoutAccountError(payoutAccountErrorCodeOf(e));
    }
  }

  @override
  Future<PayoutNameLookup> lookupAccountName({
    required String bankCode,
    required String accountNumber,
  }) async {
    final d = await _call('lookupPayoutAccountName', {
      'bankCode': bankCode,
      'accountNumber': accountNumber,
    });
    return PayoutNameLookup(
      decision: PayoutNameDecision.fromCode(d['decision']),
      holderName: _strOrNull(d['holderName']),
      verifiedName: _strOrNull(d['verifiedName']),
    );
  }

  @override
  Future<PayoutOtpTicket> requestAccountOtp({
    required String bankCode,
    required String accountNumber,
  }) async {
    final d = await _call('requestPayoutOtp', {
      'bankCode': bankCode,
      'accountNumber': accountNumber,
    });
    final last4 = d['phoneLast4'];
    if (last4 is! String) throw const PayoutAccountError('unknown');
    return PayoutOtpTicket(
      phoneLast4: last4,
      expiresInSeconds: _int(d['expiresInSeconds'], 300),
      resendInSeconds: _int(d['resendInSeconds'], 60),
    );
  }

  @override
  Future<({String accountId, String accountLast4, DateTime activeFrom})>
  saveAccount({
    required String bankCode,
    required String accountNumber,
    String? otpCode,
  }) async {
    final d = await _call('savePayoutAccount', {
      'bankCode': bankCode,
      'accountNumber': accountNumber,
      'otpCode': ?otpCode,
    });
    final id = d['accountId'];
    final last4 = d['accountLast4'];
    if (id is! String || last4 is! String) {
      throw const PayoutAccountError('unknown');
    }
    final from = d['activeFrom'];
    // The save went through; a missing time reads "now" and the account view
    // listener carries the stored one.
    final activeFrom =
        (from is String ? DateTime.tryParse(from)?.toUtc() : null) ??
        DateTime.now().toUtc();
    return (accountId: id, accountLast4: last4, activeFrom: activeFrom);
  }
}
