import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:photobooking/core/core.dart';
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

  // #203 adds startFee(PayMethod, {renew}) and checkFee().

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

  /// The server's `feeRequired` (#135: false).
  bool feeRequired;

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
    kind: VerificationKind.individual,
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
  Future<IdentitySession> startIdentity(IdentityMethod method) async {
    _record('startIdentityVerification', {'method': method.code});
    // As the server: a passed identity cannot start again, the 4th start of
    // a Vietnam day is refused, and every start counts a try.
    final current = _state();
    if (current.identityPassed) {
      throw const VerificationError('conflict');
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
    _update((d) {
      final left = d['freeResubmitsLeft'];
      return d
        ..['status'] = 'submitted'
        ..['submittedAt'] = _now()
        ..['decidedAt'] = null
        ..['rejectReason'] = null
        ..['freeResubmitsLeft'] = left is int && left > 0 ? left - 1 : 0;
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
