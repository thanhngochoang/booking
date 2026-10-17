import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/payments/payment_instructions.dart';
import 'package:photobooking/data/payments/payments_repository.dart';
import 'package:photobooking/data/verification/verification.dart';

/// A refusal from a verification callable, with the domain code the server
/// sent (`not_eligible`, `rate_limited`, `underage`, `identity_in_use`,
/// `conflict`, …) or `network` when the backend could not be reached.
class VerificationError implements Exception {
  const VerificationError(this.code);
  final String code;

  @override
  String toString() => 'VerificationError($code)';
}

/// What `startIdentityVerification` answers: the session to complete, and the
/// vendor page to open (null for the fake verifier).
@immutable
class IdentitySession {
  const IdentitySession({required this.sessionId, this.redirectUrl});

  final String sessionId;
  final String? redirectUrl;
}

/// What `lookupTaxCode` answers (public registry data).
@immutable
class TaxCodeInfo {
  const TaxCodeInfo({
    required this.name,
    required this.address,
    required this.active,
    required this.kind,
  });

  final String name;
  final String address;

  /// The registry status is `active`.
  final bool active;

  /// `company` or `household`.
  final String kind;
}

/// S21 verification: the owner's `verifications/{uid}` document and the
/// callables that move it (the server does every write).
abstract class VerificationRepository {
  /// `verifications/{uid}` now and after every change; null while missing.
  Stream<Map<String, dynamic>?> watchRaw(String uid);

  /// After the phone was linked to the Auth account: the server compares it
  /// with the contact phone and sets `phoneVerified`.
  Future<void> confirmPhoneVerified();

  /// `startVerificationFee {method, renew?}` (#203): V1's payment
  /// instructions for the fee (bank QR → S04.04's VietQR; a wallet → its
  /// `payUrl`). The same method again reuses the open payment; [renew]
  /// expires it and issues a new code ("Tạo QR mới").
  Future<PaymentInstructions> startFee(PayMethod method, {bool renew = false});

  /// `checkVerificationFee {}` (#203, S04.04's "Kiểm tra lại" and resume):
  /// asks the gateway about the open fee payments; the live one, if unpaid.
  Future<PaymentCheck> checkFee();

  Future<IdentitySession> startIdentity(IdentityMethod method);

  /// Returns the masked legal name.
  Future<String> completeIdentity(String sessionId);

  Future<void> acceptRules(String version);

  Future<void> submit();

  Future<void> resubmit();

  Future<TaxCodeInfo> lookupTaxCode(String taxCode);

  Future<BusinessStatus> submitBusiness({
    required String taxCode,
    String? docPath,
  });
}

/// One call the fake received: the callable it stands for and its payload.
typedef VerificationCall = ({String name, Map<String, Object?> data});

/// In-memory [VerificationRepository] for tests. Records every call under the
/// callable's name with the payload the server documents; [failWith] makes
/// every call throw `VerificationError(failWith)` (after recording it).
/// Calls move the document of [uid] roughly as the server would, so screens
/// see their effect through [watchRaw].
class FakeVerificationRepository implements VerificationRepository {
  FakeVerificationRepository({
    this.uid = 'u1',
    DateTime Function()? now,
    this.identitySession = const IdentitySession(sessionId: 'fake-session'),
    this.maskedName = 'NGUYỄN M** T**',
    this.taxInfo = const TaxCodeInfo(
      name: 'CÔNG TY TNHH STUDIO THỬ 5678',
      address: '12 Nguyễn Huệ, Phường Sài Gòn, TP. Hồ Chí Minh',
      active: true,
      kind: 'company',
    ),
    this.businessResult = BusinessStatus.submitted,
    this.phoneVerified = true,
    this.feeRequired = false,
    this.kind = VerificationKind.individual,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  /// Whose document the calls change.
  final String uid;
  final DateTime Function() _now;

  IdentitySession identitySession;
  String maskedName;
  TaxCodeInfo taxInfo;
  BusinessStatus businessResult;

  /// When set, every call throws `VerificationError(failWith)`.
  String? failWith;

  /// The contact's `phoneVerified` flag the server reads (Decision 3) when
  /// [submit] and [resubmit] check the steps; [confirmPhoneVerified] sets it.
  /// Defaults to true so a seeded ready doc can be sent as is.
  bool phoneVerified;

  /// The server's `feeRequired` (true since #203; false keeps #135's three
  /// steps).
  bool feeRequired;

  /// The kind of the provider type the server reads (the fee amount).
  VerificationKind kind;

  /// The fee payments issued so far, newest last ([startFee]).
  final feePayments = <PaymentInstructions>[];

  /// The instructions [startFee] answered last.
  PaymentInstructions? get lastFeeInstructions =>
      feePayments.isEmpty ? null : feePayments.last;

  /// Open (unpaid, not renewed) fee payment per method, as the server's
  /// `instructionsOf` reuse.
  final _openFee = <PayMethod, PaymentInstructions>{};

  final calls = <VerificationCall>[];

  /// The method of the last started identity session.
  IdentityMethod? _sessionMethod;

  /// Open [watchRaw] subscriptions.
  int watchers = 0;

  final _docs = <String, Map<String, dynamic>>{};
  final _changes = StreamController<String>.broadcast();

  /// Test setup: replaces the document of [docUid] (null removes it).
  void seed(String docUid, Map<String, dynamic>? doc) {
    if (doc == null) {
      _docs.remove(docUid);
    } else {
      _docs[docUid] = Map.of(doc);
    }
    _changes.add(docUid);
  }

  Map<String, dynamic>? doc(String docUid) => _docs[docUid];

  @override
  Stream<Map<String, dynamic>?> watchRaw(String docUid) {
    late final StreamController<Map<String, dynamic>?> out;
    StreamSubscription<String>? inner;
    out = StreamController<Map<String, dynamic>?>(
      onListen: () {
        watchers++;
        out.add(_docs[docUid]);
        inner = _changes.stream
            .where((u) => u == docUid)
            .listen((_) => out.add(_docs[docUid]));
      },
      onCancel: () async {
        watchers--;
        await inner?.cancel();
      },
    );
    return out.stream;
  }

  void _record(String name, [Map<String, Object?> data = const {}]) {
    calls.add((name: name, data: data));
    final code = failWith;
    if (code != null) {
      throw VerificationError(code);
    }
  }

  /// Applies [change] to the steps and top level of [uid]'s document.
  void _update(Map<String, dynamic> Function(Map<String, dynamic> d) change) {
    final d = Map<String, dynamic>.of(
      _docs[uid] ??
          {'uid': uid, 'status': 'not_started', 'freeResubmitsLeft': 1},
    );
    d['steps'] = Map<String, dynamic>.of(
      (d['steps'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final next = change(d);
    next['updatedAt'] = _now();
    _docs[uid] = next;
    _changes.add(uid);
  }

  /// [uid]'s doc read as the server's use cases see it.
  VerificationState _state() => verificationFromFirestore(
    _docs[uid],
    phoneVerified: phoneVerified,
    kind: kind,
    feeRequired: feeRequired,
    now: _now(),
  );

  Map<String, dynamic> _started(Map<String, dynamic> d) =>
      d['status'] == 'not_started' ? (d..['status'] = 'in_progress') : d;

  @override
  Future<void> confirmPhoneVerified() async {
    _record('confirmPhoneVerified');
    phoneVerified = true;
    _update((d) {
      (d['steps'] as Map<String, dynamic>)['phone'] = {'doneAt': _now()};
      return _started(d);
    });
  }

  @override
  Future<PaymentInstructions> startFee(
    PayMethod method, {
    bool renew = false,
  }) async {
    _record('startVerificationFee', {
      'method': method.code,
      if (renew) 'renew': true,
    });
    // As the server: a paid or waived fee, or a record past the steps, is
    // `not_eligible`.
    final current = _state();
    final open =
        current.status == VerificationStatus.notStarted ||
        current.status == VerificationStatus.inProgress ||
        current.status == VerificationStatus.rejected;
    if (!open || current.isDone(VerifyStep.fee)) {
      throw const VerificationError('not_eligible');
    }
    final live = _openFee[method];
    if (!renew && live != null && !live.isExpiredAt(_now())) {
      feePayments.add(live);
      return live;
    }
    final n = feePayments.length + 1;
    final id = 'vfee-$uid-$n';
    final code = 'PB VF${n.toString().padLeft(4, '0')}';
    final inst = PaymentInstructions(
      paymentId: id,
      method: method,
      amount: verificationFeeVnd[current.kind]!,
      expiresAt: _now().add(const Duration(minutes: 15)),
      transferCode: code,
      attempt: n,
      qrPayload: method == PayMethod.bankQr ? '000201010212$n' : null,
      bankName: method == PayMethod.bankQr ? 'BIDV' : null,
      accountMasked: method == PayMethod.bankQr ? '9624 •••• 3812' : null,
      payUrl: method == PayMethod.bankQr
          ? null
          : 'https://fake-pay.local/${method.code}?paymentId=$id',
    );
    _openFee[method] = inst;
    feePayments.add(inst);
    _update(_started);
    return inst;
  }

  @override
  Future<PaymentCheck> checkFee() async {
    _record('checkVerificationFee');
    final paid = _state().feePaidAt != null;
    return PaymentCheck(
      paid: paid,
      instructions: paid ? null : lastFeeInstructions,
    );
  }

  /// Test helper: the gateway's transfer settled [paymentId] (V1's
  /// settlement through the fee settler), recording `steps.fee`.
  void settleFee(String paymentId) {
    final inst = feePayments.lastWhere(
      (p) => p.paymentId == paymentId,
      orElse: () => throw StateError('unknown fee payment $paymentId'),
    );
    _openFee.clear();
    _update((d) {
      (d['steps'] as Map<String, dynamic>)['fee'] = {
        'paymentId': paymentId,
        'amount': inst.amount,
        'paidAt': _now(),
      };
      d['kind'] = _state().kind.code;
      return _started(d);
    });
  }

  @override
  Future<IdentitySession> startIdentity(IdentityMethod method) async {
    _record('startIdentityVerification', {'method': method.code});
    // As the server: a passed identity cannot start again, the fee must be
    // recorded first (#203), the 4th start of a Vietnam day is refused, and
    // every start counts a try.
    final current = _state();
    if (current.identityPassed) {
      throw const VerificationError('conflict');
    }
    if (feeRequired && current.feePaidAt == null) {
      throw const VerificationError('not_eligible');
    }
    if (current.identityAttemptsLeft == 0) {
      throw const VerificationError('rate_limited');
    }
    _sessionMethod = method;
    final today = vnDateKey(_now());
    _update((d) {
      final attempts = d['identityAttempts'];
      final count = attempts is Map && attempts['dayKey'] == today
          ? (attempts['count'] as num? ?? 0).toInt()
          : 0;
      d['identityAttempts'] = {'dayKey': today, 'count': count + 1};
      d['identitySession'] = {
        'id': identitySession.sessionId,
        'method': method.code,
        'startedAt': _now(),
      };
      return _started(d);
    });
    return identitySession;
  }

  @override
  Future<String> completeIdentity(String sessionId) async {
    _record('completeIdentityVerification', {'sessionId': sessionId});
    _update((d) {
      (d['steps'] as Map<String, dynamic>)['identity'] = {
        'method': (_sessionMethod ?? IdentityMethod.vneid).code,
        'checkedAt': _now(),
        'result': 'passed',
        'failure': null,
        'maskedName': maskedName,
      };
      d['identitySession'] = null;
      return _started(d);
    });
    return maskedName;
  }

  @override
  Future<void> acceptRules(String version) async {
    _record('acceptVerificationRules', {'version': version});
    _update((d) {
      (d['steps'] as Map<String, dynamic>)['rules'] = {
        'acceptedAt': _now(),
        'version': version,
      };
      return _started(d);
    });
  }

  @override
  Future<void> submit() async {
    _record('submitVerification');
    if (!_state().canSubmit) {
      throw const VerificationError('not_eligible');
    }
    _update(
      (d) => d
        ..['status'] = 'submitted'
        ..['submittedAt'] = _now(),
    );
  }

  @override
  Future<void> resubmit() async {
    _record('resubmitVerification');
    if (!_state().resubmittable) {
      throw const VerificationError('not_eligible');
    }
    final before = _state();
    final paidAt = before.feePaidAt;
    final decidedAt = before.decidedAt;
    // A fee paid while rejected is that paid resubmit (domain
    // `feePaidAfterRejection`).
    final paidAfterRejection =
        paidAt != null && decidedAt != null && paidAt.isAfter(decidedAt);
    _update((d) {
      final left = d['freeResubmitsLeft'];
      final free = left is int && left > 0;
      if (!free && feeRequired && !paidAfterRejection) {
        // Paid resubmit (#203): back to the steps with the fee open under a
        // new attempt.
        final attempt = d['feeAttempt'];
        (d['steps'] as Map<String, dynamic>)['fee'] = null;
        return d
          ..['status'] = 'in_progress'
          ..['feeAttempt'] = (attempt is int ? attempt : 1) + 1
          ..['submittedAt'] = null
          ..['decidedAt'] = null
          ..['rejectReason'] = null;
      }
      return d
        ..['status'] = 'submitted'
        ..['submittedAt'] = _now()
        ..['decidedAt'] = null
        ..['rejectReason'] = null
        ..['freeResubmitsLeft'] = free ? left - 1 : 0;
    });
  }

  @override
  Future<TaxCodeInfo> lookupTaxCode(String taxCode) async {
    _record('lookupTaxCode', {'taxCode': taxCode});
    return taxInfo;
  }

  @override
  Future<BusinessStatus> submitBusiness({
    required String taxCode,
    String? docPath,
  }) async {
    _record('submitBusinessVerification', {
      'taxCode': taxCode,
      'docPath': ?docPath,
    });
    _update(
      (d) => d
        ..['business'] = {
          'status': businessResult.code,
          'kind': taxInfo.kind,
          'taxCode': taxCode,
          'name': taxInfo.name,
          'address': taxInfo.address,
          'registryStatus': taxInfo.active ? 'active' : 'inactive',
          'docPath': docPath,
          'submittedAt': _now(),
          'rejectReason': null,
        },
    );
    return businessResult;
  }
}
