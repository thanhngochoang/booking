import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/verification/firestore_verification_repository.dart';
import 'package:photobooking/data/verification/verification.dart';
import 'package:photobooking/data/verification/verification_providers.dart';
import 'package:photobooking/data/verification/verification_repository.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

/// Every repository call with the callable it must reach and the payload the
/// server documents (Contract §Callables), and what it answers.
typedef _Case = ({
  String callable,
  Map<String, Object?> payload,
  Object? answer,
  Future<Object?> Function(VerificationRepository r) run,
  Object? expected,
});

/// `steps.fee` once the fee settled (#203).
final _paidFee = {
  'paymentId': 'pay1',
  'amount': 99000,
  'paidAt': DateTime.utc(2026, 10, 15, 2),
};

final List<_Case> _cases = [
  (
    callable: 'confirmPhoneVerified',
    payload: const {},
    answer: const {'phoneVerified': true},
    run: (r) async => r.confirmPhoneVerified(),
    expected: null,
  ),
  (
    callable: 'startIdentityVerification',
    payload: const {'method': 'nfc'},
    answer: const {'sessionId': 'sess1', 'redirectUrl': null},
    run: (r) async {
      final s = await r.startIdentity(IdentityMethod.nfc);
      return (s.sessionId, s.redirectUrl);
    },
    expected: ('sess1', null),
  ),
  (
    callable: 'completeIdentityVerification',
    payload: const {'sessionId': 'sess1'},
    answer: const {'result': 'passed', 'maskedName': 'NGUYỄN M** T**'},
    run: (r) => r.completeIdentity('sess1'),
    expected: 'NGUYỄN M** T**',
  ),
  (
    callable: 'acceptVerificationRules',
    payload: const {'version': '2026-10-06'},
    answer: const <String, Object?>{},
    run: (r) async => r.acceptRules(providerRulesVersion),
    expected: null,
  ),
  (
    callable: 'submitVerification',
    payload: const {},
    answer: const {'status': 'submitted'},
    run: (r) async => r.submit(),
    expected: null,
  ),
  (
    callable: 'resubmitVerification',
    payload: const {},
    answer: const {'status': 'submitted'},
    run: (r) async => r.resubmit(),
    expected: null,
  ),
  (
    callable: 'lookupTaxCode',
    payload: const {'taxCode': '0312345678'},
    answer: const {
      'name': 'CÔNG TY TNHH STUDIO THỬ 5678',
      'address': '12 Nguyễn Huệ, Phường Sài Gòn, TP. Hồ Chí Minh',
      'status': 'active',
      'kind': 'company',
    },
    run: (r) async {
      final t = await r.lookupTaxCode('0312345678');
      return (t.name, t.address, t.active, t.kind);
    },
    expected: (
      'CÔNG TY TNHH STUDIO THỬ 5678',
      '12 Nguyễn Huệ, Phường Sài Gòn, TP. Hồ Chí Minh',
      true,
      'company',
    ),
  ),
  (
    callable: 'submitBusinessVerification',
    payload: const {
      'taxCode': '0312345678',
      'docPath': 'businessDocs/u1/01J.jpg',
    },
    answer: const {'status': 'submitted'},
    run: (r) => r.submitBusiness(
      taxCode: '0312345678',
      docPath: 'businessDocs/u1/01J.jpg',
    ),
    expected: BusinessStatus.submitted,
  ),
  (
    callable: 'submitBusinessVerification',
    payload: const {'taxCode': '079095001234'},
    answer: const {'status': 'approved'},
    run: (r) => r.submitBusiness(taxCode: '079095001234'),
    expected: BusinessStatus.approved,
  ),
];

void main() {
  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  group('FirestoreVerificationRepository', () {
    late FakeFirebaseFirestore db;
    late _MockFunctions functions;
    late FirestoreVerificationRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      functions = _MockFunctions();
      repo = FirestoreVerificationRepository(db: db, functions: functions);
    });

    _MockCallable stub(String name, Object? answer) {
      final c = _MockCallable();
      final result = _MockResult();
      when(() => result.data).thenReturn(answer);
      when(() => c.call<Object?>(any())).thenAnswer((_) async => result);
      when(() => functions.httpsCallable(name, options: any(named: 'options')))
          .thenReturn(c);
      return c;
    }

    test('callables send the documented payloads', () async {
      for (final c in _cases) {
        final callable = stub(c.callable, c.answer);
        final got = await c.run(repo);
        expect(got, c.expected, reason: c.callable);
        final sent = verify(() => callable.call<Object?>(captureAny()))
            .captured
            .single;
        expect(sent, c.payload, reason: c.callable);
      }
    });

    test('startFee and checkFee send the documented payloads', () async {
      final qr = {
        'paymentId': 'pay1',
        'method': 'bank_qr',
        'amount': 99000,
        'expiresAt': '2026-10-15T03:15:00.000Z',
        'transferCode': 'PB 7F3K2Q',
        'attempt': 1,
        'qrPayload': '000201',
        'bankName': 'BIDV',
        'accountMasked': '9624 •••• 3812',
      };
      var callable = stub('startVerificationFee', qr);
      final inst = await repo.startFee(PayMethod.bankQr);
      expect(inst.paymentId, 'pay1');
      expect(inst.method, PayMethod.bankQr);
      expect(inst.amount, 99000);
      expect(inst.expiresAt, DateTime.utc(2026, 10, 15, 3, 15));
      expect(inst.transferCode, 'PB 7F3K2Q');
      expect(inst.qrPayload, '000201');
      expect(
        verify(() => callable.call<Object?>(captureAny())).captured.single,
        {'method': 'bank_qr'},
      );

      callable = stub('startVerificationFee', {
        ...qr,
        'method': 'zalopay',
        'payUrl': 'https://fake-pay.local/zalopay?paymentId=pay2',
        'paymentId': 'pay2',
      });
      final renewed = await repo.startFee(PayMethod.zaloPay, renew: true);
      expect(renewed.paymentId, 'pay2');
      expect(renewed.payUrl, 'https://fake-pay.local/zalopay?paymentId=pay2');
      expect(
        verify(() => callable.call<Object?>(captureAny())).captured.single,
        {'method': 'zalopay', 'renew': true},
      );

      callable = stub('checkVerificationFee', {
        'paid': false,
        'instructions': qr,
      });
      final open = await repo.checkFee();
      expect(open.paid, isFalse);
      expect(open.instructions?.paymentId, 'pay1');
      expect(
        verify(() => callable.call<Object?>(captureAny())).captured.single,
        const <String, Object?>{},
      );
      stub('checkVerificationFee', {'paid': true, 'instructions': null});
      final paid = await repo.checkFee();
      expect(paid.paid, isTrue);
      expect(paid.instructions, isNull);

      // A reply without instructions is a bad response, not a payment.
      stub('startVerificationFee', const <String, Object?>{});
      await expectLater(
        repo.startFee(PayMethod.momo),
        throwsA(isA<VerificationError>()),
      );
    });

    test('an inactive tax code reads active false', () async {
      stub('lookupTaxCode', {
        'name': 'X',
        'address': 'Y',
        'status': 'inactive',
        'kind': 'company',
      });
      expect((await repo.lookupTaxCode('0312340000')).active, isFalse);
    });

    test('details.code becomes VerificationError(code)', () async {
      final c = _MockCallable();
      when(() => functions.httpsCallable(any(), options: any(named: 'options')))
          .thenReturn(c);
      when(() => c.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(
          message: 'rate_limited',
          code: 'resource-exhausted',
          details: {'code': 'rate_limited'},
        ),
      );
      await expectLater(
        repo.startIdentity(IdentityMethod.vneid),
        throwsA(
          isA<VerificationError>().having(
            (e) => e.code,
            'code',
            'rate_limited',
          ),
        ),
      );
      // Without details, the transport code is what is left.
      when(() => c.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(message: 'boom', code: 'internal'),
      );
      await expectLater(
        repo.submit(),
        throwsA(
          isA<VerificationError>().having((e) => e.code, 'code', 'internal'),
        ),
      );
    });

    test('unavailable becomes network', () async {
      final c = _MockCallable();
      when(() => functions.httpsCallable(any(), options: any(named: 'options')))
          .thenReturn(c);
      for (final transport in ['unavailable', 'deadline-exceeded']) {
        when(
          () => c.call<Object?>(any()),
        ).thenThrow(FirebaseFunctionsException(message: 'x', code: transport));
        await expectLater(
          repo.confirmPhoneVerified(),
          throwsA(
            isA<VerificationError>().having((e) => e.code, 'code', 'network'),
          ),
          reason: transport,
        );
      }
    });

    test('an exception other than FirebaseFunctionsException becomes network, '
        'an error unknown', () async {
      final c = _MockCallable();
      when(() => functions.httpsCallable(any(), options: any(named: 'options')))
          .thenReturn(c);
      for (final e in <Exception>[
        PlatformException(code: 'channel-error'),
        TimeoutException('call'),
        const FormatException('bad'),
      ]) {
        when(() => c.call<Object?>(any())).thenThrow(e);
        await expectLater(
          repo.startIdentity(IdentityMethod.vneid),
          throwsA(
            isA<VerificationError>().having((e) => e.code, 'code', 'network'),
          ),
          reason: '$e',
        );
      }
      when(() => c.call<Object?>(any())).thenThrow(StateError('boom'));
      await expectLater(
        repo.completeIdentity('s1'),
        throwsA(
          isA<VerificationError>().having((e) => e.code, 'code', 'unknown'),
        ),
      );
    });

    test('callables run in the app region with a timeout', () async {
      stub('submitVerification', const {'status': 'submitted'});
      await repo.submit();
      final options =
          verify(
                () => functions.httpsCallable(
                  'submitVerification',
                  options: captureAny(named: 'options'),
                ),
              ).captured.single
              as HttpsCallableOptions;
      expect(
        options.timeout,
        greaterThanOrEqualTo(const Duration(seconds: 10)),
      );
    });

    test('watchRaw streams verifications/{uid}; missing is null', () async {
      expect(await repo.watchRaw('u1').first, isNull);
      await db.collection('verifications').doc('u1').set({
        'status': 'submitted',
        'submittedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 15)),
      });
      final d = await repo.watchRaw('u1').first;
      expect(d!['status'], 'submitted');
    });
  });

  group('FakeVerificationRepository', () {
    test('callables send the documented payloads', () async {
      for (final c in _cases) {
        final fake = FakeVerificationRepository(
          identitySession: const IdentitySession(sessionId: 'sess1'),
          maskedName: 'NGUYỄN M** T**',
          taxInfo: const TaxCodeInfo(
            name: 'CÔNG TY TNHH STUDIO THỬ 5678',
            address: '12 Nguyễn Huệ, Phường Sài Gòn, TP. Hồ Chí Minh',
            active: true,
            kind: 'company',
          ),
          businessResult: c.expected is BusinessStatus
              ? c.expected! as BusinessStatus
              : BusinessStatus.submitted,
        );
        // A doc the server would accept the call on.
        fake.seed('u1', {
          'status': switch (c.callable) {
            'resubmitVerification' => 'rejected',
            _ => 'in_progress',
          },
          'rejectReason': {'code': 'other'},
          'steps': {
            // A passed identity cannot start again (`conflict`).
            if (c.callable != 'startIdentityVerification')
              'identity': {'result': 'passed'},
            'rules': {'acceptedAt': DateTime.utc(2026, 10, 15)},
          },
        });
        final got = await c.run(fake);
        expect(got, c.expected, reason: c.callable);
        expect(fake.calls.single.name, c.callable);
        expect(fake.calls.single.data, c.payload, reason: c.callable);
      }
    });

    test(
      'startIdentity counts a try like the server and refuses the 4th',
      () async {
        final fake = FakeVerificationRepository(
          now: () => DateTime.utc(2026, 10, 15, 2),
        );
        for (var i = 1; i <= 3; i++) {
          await fake.startIdentity(IdentityMethod.nfc);
          expect(fake.doc('u1')!['identityAttempts'], {
            'dayKey': '2026-10-15',
            'count': i,
          });
        }
        expect((fake.doc('u1')!['identitySession'] as Map)['method'], 'nfc');
        await expectLater(
          fake.startIdentity(IdentityMethod.vneid),
          throwsA(
            isA<VerificationError>().having(
              (e) => e.code,
              'code',
              'rate_limited',
            ),
          ),
        );
        await fake.completeIdentity('fake-session');
        expect(fake.doc('u1')!['identitySession'], isNull);
        expect(
          ((fake.doc('u1')!['steps'] as Map)['identity'] as Map)['method'],
          'nfc',
        );
      },
    );

    test('failWith throws VerificationError(code) and still records', () async {
      final fake = FakeVerificationRepository()..failWith = 'not_eligible';
      await expectLater(
        fake.submit(),
        throwsA(
          isA<VerificationError>().having(
            (e) => e.code,
            'code',
            'not_eligible',
          ),
        ),
      );
      expect(fake.calls.single.name, 'submitVerification');
    });

    test('steps move the seeded doc like the server', () async {
      final at = DateTime.utc(2026, 10, 15, 3);
      final fake = FakeVerificationRepository(uid: 'u1', now: () => at);
      final seen = <Map<String, dynamic>?>[];
      final sub = fake.watchRaw('u1').listen(seen.add);
      addTearDown(sub.cancel);

      await fake.confirmPhoneVerified();
      await fake.completeIdentity('sess1');
      await fake.acceptRules(providerRulesVersion);
      var s = verificationFromFirestore(
        fake.doc('u1'),
        phoneVerified: true,
        kind: VerificationKind.individual,
        feeRequired: false,
        now: at,
      );
      expect(s.status, VerificationStatus.inProgress);
      expect(s.canSubmit, isTrue);

      await fake.submit();
      s = verificationFromFirestore(
        fake.doc('u1'),
        phoneVerified: true,
        kind: VerificationKind.individual,
        feeRequired: false,
        now: at,
      );
      expect(s.status, VerificationStatus.submitted);
      expect(s.submittedAt, at);
      await Future<void>.delayed(Duration.zero);
      expect(seen.first, isNull);
      expect(seen.last!['status'], 'submitted');
    });
  });

  group('FakeVerificationRepository fee', () {
    test(
      'startFee records the payload, reuses the open payment per method '
      'and renew issues a new one; checkFee answers paid after settleFee',
      () async {
        final fake = FakeVerificationRepository(
          uid: 'u1',
          now: () => DateTime.utc(2026, 10, 15, 3),
          feeRequired: true,
        )..seed('u1', {'status': 'in_progress', 'steps': <String, dynamic>{}});

        final qr = await fake.startFee(PayMethod.bankQr);
        expect(qr.method, PayMethod.bankQr);
        expect(qr.amount, 99000);
        expect(qr.qrPayload, isNotNull);
        expect(qr.expiresAt, DateTime.utc(2026, 10, 15, 3, 15));
        expect(fake.calls.last.name, 'startVerificationFee');
        expect(fake.calls.last.data, {'method': 'bank_qr'});
        expect((await fake.startFee(PayMethod.bankQr)).paymentId, qr.paymentId);

        final momo = await fake.startFee(PayMethod.momo);
        expect(momo.paymentId, isNot(qr.paymentId));
        expect(momo.payUrl, isNotNull);

        final renewed = await fake.startFee(PayMethod.bankQr, renew: true);
        expect(fake.calls.last.data, {'method': 'bank_qr', 'renew': true});
        expect(renewed.paymentId, isNot(qr.paymentId));

        var check = await fake.checkFee();
        expect(fake.calls.last.name, 'checkVerificationFee');
        expect(fake.calls.last.data, isEmpty);
        expect(check.paid, isFalse);
        expect(check.instructions?.paymentId, renewed.paymentId);

        fake.settleFee(renewed.paymentId);
        final fee = (fake.doc('u1')!['steps'] as Map)['fee'] as Map;
        expect(fee['paymentId'], renewed.paymentId);
        expect(fee['amount'], 99000);
        check = await fake.checkFee();
        expect(check.paid, isTrue);
        expect(check.instructions, isNull);

        // A paid fee cannot start again.
        await expectLater(
          fake.startFee(PayMethod.bankQr),
          throwsA(
            isA<VerificationError>().having(
              (e) => e.code,
              'code',
              'not_eligible',
            ),
          ),
        );
      },
    );

    test('a studio pays 299.000₫', () async {
      final fake = FakeVerificationRepository(
        uid: 'u1',
        feeRequired: true,
        kind: VerificationKind.studio,
      );
      expect((await fake.startFee(PayMethod.bankQr)).amount, 299000);
    });

    test('resubmit with no free resubmit left goes back to in_progress with '
        'the fee open under a new attempt', () async {
      final fake = FakeVerificationRepository(uid: 'u1', feeRequired: true)
        ..seed('u1', {
          'status': 'rejected',
          'rejectReason': {'code': 'other'},
          'freeResubmitsLeft': 0,
          'feeAttempt': 1,
          'submittedAt': DateTime.utc(2026, 10, 14),
          'steps': {
            'fee': {
              'paymentId': 'pay1',
              'amount': 99000,
              'paidAt': DateTime.utc(2026, 10, 14),
            },
            'identity': {'result': 'passed'},
            'rules': {'acceptedAt': DateTime.utc(2026, 10, 14)},
          },
        });
      await fake.resubmit();
      final d = fake.doc('u1')!;
      expect(d['status'], 'in_progress');
      expect((d['steps'] as Map)['fee'], isNull);
      expect(d['feeAttempt'], 2);
      expect(d['submittedAt'], isNull);
    });
  });

  group('FakeVerificationRepository gates', () {
    Map<String, dynamic> rejected({bool identity = true}) => {
      'status': 'rejected',
      'rejectReason': {'code': 'identity_mismatch'},
      'freeResubmitsLeft': 1,
      'steps': {
        'identity': identity
            ? {'result': 'passed', 'maskedName': 'AN B**'}
            : null,
        'rules': {'acceptedAt': DateTime.utc(2026, 10, 15), 'version': 'v'},
      },
    };

    Future<void> expectNotEligible(Future<void> call) => expectLater(
      call,
      throwsA(
        isA<VerificationError>().having((e) => e.code, 'code', 'not_eligible'),
      ),
    );

    test('resubmit refuses a missing step like the server', () async {
      final fake = FakeVerificationRepository(uid: 'u1')
        ..seed('u1', rejected(identity: false));
      await expectNotEligible(fake.resubmit());
      expect(fake.doc('u1')!['status'], 'rejected');
      expect(fake.calls.single.name, 'resubmitVerification');

      fake.seed('u1', rejected());
      fake.phoneVerified = false;
      await expectNotEligible(fake.resubmit());

      fake.phoneVerified = true;
      await fake.resubmit();
      expect(fake.doc('u1')!['status'], 'submitted');
      expect(fake.doc('u1')!['freeResubmitsLeft'], 0);
    });

    test('resubmit refuses a final reason', () async {
      final fake = FakeVerificationRepository(uid: 'u1')
        ..seed('u1', {
          ...rejected(),
          'rejectReason': {'code': 'duplicate_account'},
        });
      await expectNotEligible(fake.resubmit());
    });

    test('submit needs every step on an in_progress record', () async {
      final fake = FakeVerificationRepository(uid: 'u1');
      await expectNotEligible(fake.submit());
      fake.seed('u1', {...rejected(), 'status': 'in_progress'});
      await fake.submit();
      expect(fake.doc('u1')!['status'], 'submitted');
    });
  });

  group('myVerificationProvider', () {
    late FakeVerificationRepository verifications;
    late FakeUserContactRepository contacts;
    late FakePhotographerIntroRepository intros;
    late ProviderContainer container;

    setUp(() {
      verifications = FakeVerificationRepository(uid: 'u1');
      contacts = FakeUserContactRepository();
      intros = FakePhotographerIntroRepository();
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(initialUser: const AuthUser(uid: 'u1')),
          ),
          verificationRepositoryProvider.overrideWithValue(verifications),
          userContactRepositoryProvider.overrideWithValue(contacts),
          photographerIntroRepositoryProvider.overrideWithValue(intros),
          clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 15, 3)),
        ],
      );
      addTearDown(container.dispose);
    });

    Future<VerificationState> settle() async {
      final sub = container.listen(myVerificationProvider, (_, _) {});
      addTearDown(sub.close);
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      return container.read(myVerificationProvider).requireValue;
    }

    test('a missing doc is the initial state of the provider type', () async {
      intros.seed(
        'u1',
        const PhotographerIntro(providerType: ProviderType.studio),
      );
      final s = await settle();
      expect(s.status, VerificationStatus.notStarted);
      expect(s.kind, VerificationKind.studio);
      expect(s.feeRequired, isTrue);
      expect(s.requiredSteps, [
        VerifyStep.phone,
        VerifyStep.fee,
        VerifyStep.identity,
        VerifyStep.rules,
      ]);
      expect(s.phoneDone, isFalse);
      // #203 turns the fee on together with the server's feeRequired.
      expect(container.read(verificationFeeRequiredProvider), isTrue);
      expect(container.read(identityModeRealProvider), isFalse);
    });

    test(
      'updates when the contact flag flips and when the doc changes',
      () async {
        final contact = StreamController<UserContact?>();
        addTearDown(contact.close);
        final c = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(initialUser: const AuthUser(uid: 'u1')),
            ),
            verificationRepositoryProvider.overrideWithValue(verifications),
            currentContactProvider.overrideWith((ref) => contact.stream),
            photographerIntroRepositoryProvider.overrideWithValue(intros),
            clockProvider.overrideWithValue(
              () => DateTime.utc(2026, 10, 15, 3),
            ),
          ],
        );
        addTearDown(c.dispose);
        final sub = c.listen(myVerificationProvider, (_, _) {});
        addTearDown(sub.close);
        Future<VerificationState> settled() async {
          for (var i = 0; i < 10; i++) {
            await Future<void>.delayed(Duration.zero);
          }
          return c.read(myVerificationProvider).requireValue;
        }

        contact.add(const UserContact(phone: '+84903123456'));
        expect((await settled()).phoneDone, isFalse);

        // S21.01: the server sets phoneVerified after the OTP link.
        contact.add(
          const UserContact(phone: '+84903123456', phoneVerified: true),
        );
        var s = await settled();
        expect(s.phoneDone, isTrue);
        expect(s.nextStep, VerifyStep.fee);

        verifications.seed('u1', {
          'status': 'in_progress',
          'steps': {
            'fee': _paidFee,
            'identity': {'result': 'passed', 'maskedName': 'AN B**'},
          },
        });
        s = await settled();
        expect(s.status, VerificationStatus.inProgress);
        expect(s.identityPassed, isTrue);
        expect(s.phoneDone, isTrue);
        expect(s.nextStep, VerifyStep.rules);
      },
    );

    test('combines the doc, the contact flag and the provider type', () async {
      contacts.seed(
        'u1',
        const UserContact(phone: '+84903123456', phoneVerified: true),
      );
      intros.seed(
        'u1',
        const PhotographerIntro(providerType: ProviderType.artist),
      );
      verifications.seed('u1', {
        'status': 'in_progress',
        'kind': 'individual',
        'steps': {
          'fee': _paidFee,
          'identity': {'result': 'passed', 'maskedName': 'AN B**'},
        },
      });
      final s = await settle();
      expect(s.kind, VerificationKind.individual);
      expect(s.phoneDone, isTrue);
      expect(s.identityPassed, isTrue);
      expect(s.nextStep, VerifyStep.rules);
      expect(s.stepsLeft, 1);
    });
  });
}
