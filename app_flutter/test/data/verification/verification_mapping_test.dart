import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photobooking/data/verification/verification.dart';

/// Thursday 15 Oct 2026, 10:00 in Vietnam.
final _now = DateTime.utc(2026, 10, 15, 3);

Timestamp _ts(DateTime d) => Timestamp.fromDate(d);

/// A `verifications/{uid}` document as the Functions adapter writes it.
Map<String, dynamic> _doc({
  String status = 'in_progress',
  String kind = 'individual',
  Map<String, dynamic>? phone,
  Map<String, dynamic>? fee,
  Map<String, dynamic>? identity,
  Map<String, dynamic>? rules,
  Map<String, dynamic>? identityAttempts,
  Map<String, dynamic>? rejectReason,
  int freeResubmitsLeft = 1,
  Map<String, dynamic>? business,
  DateTime? submittedAt,
  DateTime? decidedAt,
}) => {
  'uid': 'u1',
  'kind': kind,
  'status': status,
  'steps': {'phone': phone, 'fee': fee, 'identity': identity, 'rules': rules},
  'identitySession': null,
  'identityAttempts': identityAttempts ?? {'dayKey': '2026-10-15', 'count': 0},
  'feeAttempt': 1,
  'submittedAt': submittedAt == null ? null : _ts(submittedAt),
  'decidedAt': decidedAt == null ? null : _ts(decidedAt),
  'decidedBy': null,
  'rejectReason': rejectReason,
  'freeResubmitsLeft': freeResubmitsLeft,
  'nudgedAt': null,
  'business': business,
  'version': 3,
  'createdAt': _ts(DateTime.utc(2026, 10, 14)),
  'updatedAt': _ts(DateTime.utc(2026, 10, 15)),
};

Map<String, dynamic> _passed({String method = 'vneid'}) => {
  'method': method,
  'checkedAt': _ts(DateTime.utc(2026, 10, 15, 2)),
  'result': 'passed',
  'failure': null,
  'maskedName': 'NGUYỄN M** T**',
};

final _rules = {
  'acceptedAt': _ts(DateTime.utc(2026, 10, 15, 2, 30)),
  'version': '2026-10-06',
};

VerificationState _map(
  Map<String, dynamic>? d, {
  bool phoneVerified = false,
  VerificationKind kind = VerificationKind.individual,
  bool feeRequired = false,
  DateTime? now,
}) => verificationFromFirestore(
  d,
  phoneVerified: phoneVerified,
  kind: kind,
  feeRequired: feeRequired,
  now: now ?? _now,
);

void main() {
  test('missing doc is not started with the kind\'s fee', () {
    final individual = _map(null);
    expect(individual.status, VerificationStatus.notStarted);
    expect(individual.kind, VerificationKind.individual);
    expect(individual.feeAmount, 99000);
    expect(individual.feePaidAt, isNull);
    expect(individual.phoneDone, isFalse);
    expect(individual.identityPassed, isFalse);
    expect(individual.freeResubmitsLeft, 1);
    expect(individual.identityAttemptsLeft, 3);
    expect(individual.business, isNull);
    expect(individual.nextStep, VerifyStep.phone);
    expect(individual.canSubmit, isFalse);
    expect(individual.resubmittable, isFalse);

    final studio = _map(null, kind: VerificationKind.studio);
    expect(studio.kind, VerificationKind.studio);
    expect(studio.feeAmount, 299000);
    expect(verificationFeeVnd[VerificationKind.studio], 299000);

    expect(
      VerificationState.initial(VerificationKind.studio).feeAmount,
      299000,
    );
  });

  test('feeRequired false gives three steps and ignores steps.fee', () {
    final noFee = _map(_doc());
    expect(noFee.feeRequired, isFalse);
    expect(noFee.requiredSteps, [
      VerifyStep.phone,
      VerifyStep.identity,
      VerifyStep.rules,
    ]);
    expect(noFee.stepsLeft, 3);

    // A stray fee step changes nothing while the fee is off.
    final paid = _map(
      _doc(
        fee: {
          'paymentId': 'pay1',
          'amount': 99000,
          'paidAt': _ts(DateTime.utc(2026, 10, 15, 1)),
        },
      ),
    );
    expect(paid.stepsLeft, 3);
    expect(paid.nextStep, VerifyStep.phone);

    final withFee = _map(_doc(), feeRequired: true);
    expect(withFee.requiredSteps, [
      VerifyStep.phone,
      VerifyStep.fee,
      VerifyStep.identity,
      VerifyStep.rules,
    ]);
    expect(withFee.stepsLeft, 4);
  });

  test('each status code maps', () {
    const codes = {
      'not_started': VerificationStatus.notStarted,
      'in_progress': VerificationStatus.inProgress,
      'submitted': VerificationStatus.submitted,
      'approved': VerificationStatus.approved,
      'rejected': VerificationStatus.rejected,
      'revoked': VerificationStatus.revoked,
    };
    for (final MapEntry(:key, :value) in codes.entries) {
      expect(_map(_doc(status: key)).status, value, reason: key);
      expect(value.code, key);
    }
    expect(_map(_doc(status: 'bogus')).status, VerificationStatus.notStarted);
  });

  test('steps map with dates', () {
    final s = _map(
      _doc(
        phone: {'doneAt': _ts(DateTime.utc(2026, 10, 15, 1))},
        fee: {
          'paymentId': 'pay1',
          'amount': 299000,
          'paidAt': _ts(DateTime.utc(2026, 10, 15, 1, 30)),
        },
        identity: _passed(method: 'nfc'),
        rules: _rules,
        submittedAt: DateTime.utc(2026, 10, 15, 2, 45),
        decidedAt: DateTime.utc(2026, 10, 15, 2, 50),
      ),
      phoneVerified: true,
      kind: VerificationKind.studio,
      feeRequired: true,
    );
    expect(s.feeAmount, 299000);
    expect(s.feePaidAt, DateTime.utc(2026, 10, 15, 1, 30));
    expect(s.feePaidAt!.isUtc, isTrue);
    expect(s.identityPassed, isTrue);
    expect(s.identityMethod, IdentityMethod.nfc);
    expect(s.maskedName, 'NGUYỄN M** T**');
    expect(s.identityFailure, isNull);
    expect(s.rulesAcceptedAt, DateTime.utc(2026, 10, 15, 2, 30));
    expect(s.submittedAt, DateTime.utc(2026, 10, 15, 2, 45));
    expect(s.decidedAt, DateTime.utc(2026, 10, 15, 2, 50));
    expect(s.stepsLeft, 0);
    expect(s.nextStep, isNull);
    expect(s.canSubmit, isTrue);

    final failed = _map(
      _doc(
        identity: {
          'method': 'vneid',
          'checkedAt': _ts(DateTime.utc(2026, 10, 15, 2)),
          'result': 'failed',
          'failure': 'underage',
          'maskedName': null,
        },
      ),
    );
    expect(failed.identityPassed, isFalse);
    expect(failed.identityFailure, 'underage');
    expect(failed.identityMethod, IdentityMethod.vneid);
    expect(failed.maskedName, isNull);

    // Dates written as ISO strings or DateTime (fakes) read the same.
    final iso = _map({
      ..._doc(),
      'submittedAt': '2026-10-15T02:45:00.000Z',
      'decidedAt': DateTime.utc(2026, 10, 15, 2, 50),
    });
    expect(iso.submittedAt, DateTime.utc(2026, 10, 15, 2, 45));
    expect(iso.decidedAt, DateTime.utc(2026, 10, 15, 2, 50));
  });

  test('phone step comes from the contact flag', () {
    final done = _map(_doc(), phoneVerified: true);
    expect(done.phoneDone, isTrue);
    expect(done.nextStep, VerifyStep.identity);

    // steps.phone mirrors the flag; a number changed since then resets the
    // flag and the step shows undone again (Decision 3).
    final reset = _map(
      _doc(phone: {'doneAt': _ts(DateTime.utc(2026, 10, 14))}),
      phoneVerified: false,
    );
    expect(reset.phoneDone, isFalse);
    expect(reset.nextStep, VerifyStep.phone);
  });

  test('nextStep and stepsLeft match the domain order', () {
    // Steps in any order; next is the first undone in phone → identity → rules.
    final rulesOnly = _map(_doc(rules: _rules));
    expect(rulesOnly.nextStep, VerifyStep.phone);
    expect(rulesOnly.stepsLeft, 2);
    expect(rulesOnly.canSubmit, isFalse);

    final phoneAndRules = _map(_doc(rules: _rules), phoneVerified: true);
    expect(phoneAndRules.nextStep, VerifyStep.identity);
    expect(phoneAndRules.stepsLeft, 1);

    final allButRules = _map(_doc(identity: _passed()), phoneVerified: true);
    expect(allButRules.nextStep, VerifyStep.rules);
    expect(allButRules.stepsLeft, 1);

    // With the fee on, the fee is second.
    final feeNext = _map(
      _doc(identity: _passed()),
      phoneVerified: true,
      feeRequired: true,
    );
    expect(feeNext.nextStep, VerifyStep.fee);
    expect(feeNext.stepsLeft, 2);

    // Only an in_progress record can be submitted (the server's rule).
    final submitted = _map(
      _doc(status: 'submitted', identity: _passed(), rules: _rules),
      phoneVerified: true,
    );
    expect(submitted.stepsLeft, 0);
    expect(submitted.canSubmit, isFalse);
  });

  test('a rejected doc exposes reason, text and resubmittable', () {
    const reasons = {
      'fake_avatar': (RejectReason.fakeAvatar, true),
      'stolen_portfolio': (RejectReason.stolenPortfolio, true),
      'identity_mismatch': (RejectReason.identityMismatch, true),
      'other': (RejectReason.other, true),
      'duplicate_account': (RejectReason.duplicateAccount, false),
      'underage': (RejectReason.underage, false),
    };
    for (final MapEntry(key: code, value: (reason, again)) in reasons.entries) {
      final s = _map(
        _doc(
          status: 'rejected',
          rejectReason: {'code': code, 'text': 'Ảnh không rõ mặt'},
          freeResubmitsLeft: 0,
        ),
      );
      expect(s.rejectReason, reason, reason: code);
      expect(s.rejectText, 'Ảnh không rõ mặt');
      expect(s.resubmittable, again, reason: code);
      expect(s.freeResubmitsLeft, 0);
      expect(reason.code, code);
    }
    final noText = _map(
      _doc(status: 'rejected', rejectReason: {'code': 'other', 'text': null}),
    );
    expect(noText.rejectText, isNull);
    expect(noText.freeResubmitsLeft, 1);

    // Not rejected: never resubmittable, even with a stale reason.
    final approved = _map(
      _doc(status: 'approved', rejectReason: {'code': 'other'}),
    );
    expect(approved.resubmittable, isFalse);
  });

  test('identity attempts left counts the VN day', () {
    // 10:00 VN on 15 Oct; two attempts today.
    expect(
      _map(_doc(identityAttempts: {'dayKey': '2026-10-15', 'count': 2}))
          .identityAttemptsLeft,
      1,
    );
    expect(
      _map(_doc(identityAttempts: {'dayKey': '2026-10-15', 'count': 5}))
          .identityAttemptsLeft,
      0,
    );
    // Yesterday's count no longer applies.
    expect(
      _map(_doc(identityAttempts: {'dayKey': '2026-10-14', 'count': 3}))
          .identityAttemptsLeft,
      3,
    );
    // 23:30 UTC on 14 Oct is already 15 Oct in Vietnam.
    expect(
      _map(
        _doc(identityAttempts: {'dayKey': '2026-10-15', 'count': 3}),
        now: DateTime.utc(2026, 10, 14, 23, 30),
      ).identityAttemptsLeft,
      0,
    );
  });

  test('business sub-record maps', () {
    final s = _map(
      _doc(
        status: 'approved',
        kind: 'studio',
        business: {
          'status': 'rejected',
          'kind': 'company',
          'taxCode': '0312345678',
          'name': 'CÔNG TY TNHH STUDIO THỬ 5678',
          'address': '12 Nguyễn Huệ, Phường Sài Gòn, TP. Hồ Chí Minh',
          'registryStatus': 'active',
          'docPath': 'businessDocs/u1/01J.jpg',
          'representativeMatched': false,
          'submittedAt': _ts(DateTime.utc(2026, 10, 15, 1)),
          'decidedAt': _ts(DateTime.utc(2026, 10, 15, 2)),
          'decidedBy': 'staff1',
          'rejectReason': {'code': 'doc_unreadable', 'text': 'Ảnh mờ'},
          'purgeAfter': _ts(DateTime.utc(2026, 11, 14)),
        },
      ),
      kind: VerificationKind.studio,
    );
    final b = s.business!;
    expect(b.status, BusinessStatus.rejected);
    expect(b.kind, 'company');
    expect(b.taxCode, '0312345678');
    expect(b.name, 'CÔNG TY TNHH STUDIO THỬ 5678');
    expect(b.address, '12 Nguyễn Huệ, Phường Sài Gòn, TP. Hồ Chí Minh');
    expect(b.rejectCode, 'doc_unreadable');
    expect(b.rejectText, 'Ảnh mờ');

    final household = _map(
      _doc(
        business: {
          'status': 'approved',
          'kind': 'household',
          'taxCode': '079095001234',
          'name': 'HỘ KINH DOANH NGUYỄN MINH TRÍ',
          'address': '',
          'registryStatus': 'active',
          'representativeMatched': true,
          'rejectReason': null,
        },
      ),
    ).business!;
    expect(household.status, BusinessStatus.approved);
    expect(household.kind, 'household');
    expect(household.rejectCode, isNull);
    expect(household.rejectText, isNull);
  });

  test('kind follows the provider type until a fee is recorded', () {
    // The doc says individual, the provider is now a studio: studio.
    expect(
      _map(_doc(kind: 'individual'), kind: VerificationKind.studio).kind,
      VerificationKind.studio,
    );
    // A paid fee freezes the doc's kind (#203).
    final frozen = _map(
      _doc(
        kind: 'individual',
        fee: {
          'paymentId': 'pay1',
          'amount': 99000,
          'paidAt': _ts(DateTime.utc(2026, 10, 15, 1)),
        },
      ),
      kind: VerificationKind.studio,
      feeRequired: true,
    );
    expect(frozen.kind, VerificationKind.individual);
    expect(frozen.feeAmount, 99000);
  });

  test('the rules version is the provider rules date', () {
    expect(providerRulesVersion, '2026-10-06');
  });
}
