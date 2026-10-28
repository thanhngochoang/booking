import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/passes/firestore_pass_repository.dart';
import 'package:photobooking/data/passes/pass_providers.dart';
import 'package:photobooking/data/passes/pass_repository.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_pass_repository.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

void main() {
  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  group('pass codes', () {
    test('normalizePassCode uppercases and strips VE- and dashes', () {
      expect(normalizePassCode('ve-7f3k-2qab'), '7F3K2QAB');
      expect(normalizePassCode('7F3K2QAB'), '7F3K2QAB');
      expect(normalizePassCode(' VE-7F3K-2QAB '), '7F3K2QAB');
      // O, I, L, U, 0, 1 are not in the alphabet.
      expect(normalizePassCode('VE-7F3K-2QA0'), isNull);
      expect(normalizePassCode('VE-7F3K'), isNull);
      expect(passDisplay('7F3K2QAB'), 'VE-7F3K-2QAB');
    });
  });

  group('FirestorePassRepository', () {
    late FakeFirebaseFirestore db;
    late _MockFunctions functions;
    late _MockCallable callable;
    late FirestorePassRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      functions = _MockFunctions();
      callable = _MockCallable();
      when(() => functions.httpsCallable(any(), options: any(named: 'options')))
          .thenReturn(callable);
      repo = FirestorePassRepository(db: db, functions: functions);
    });

    test('watchBookingPass reads bookings/{id}/private/pass', () async {
      expect(await repo.watchBookingPass('b1').first, isNull);
      await db.doc('bookings/b1/private/pass').set({'code': '7F3K2QAB'});
      expect(await repo.watchBookingPass('b1').first, '7F3K2QAB');
    });

    test('watchRegistrationPass prefers private/pass, falls back to the legacy ticketCode', () async {
      await db.doc('events/e1/registrations/r1').set({
        'ticketCode': 'VE-AB2C-1020',
      });
      expect(
        await repo.watchRegistrationPass('e1', 'r1').first,
        'VE-AB2C-1020',
      );
      await db.doc('events/e1/registrations/r1/private/pass').set({
        'code': '7F3K2QAB',
      });
      expect(await repo.watchRegistrationPass('e1', 'r1').first, '7F3K2QAB');
    });

    test('scan sends {code} and parses the summary', () async {
      final r = _MockResult();
      when(() => r.data).thenReturn({
        'booking': {'id': 'b1', 'customerName': 'Lan'},
        'registrations': [
          {
            'id': 'r1',
            'eventTitle': 'Vé vào cửa',
            'quantity': 3,
            'kind': 'entry',
          },
          {
            'id': 'r2',
            'eventTitle': 'Workshop',
            'quantity': 1,
            'kind': 'venue_gate',
          },
        ],
        'waived': {'bookingId': 'b1', 'count': 2},
        'todayCount': 41,
      });
      when(() => callable.call<Object?>(any())).thenAnswer((_) async => r);

      final res = await repo.scan('ve-7f3k-2qab');

      verify(
        () =>
            functions.httpsCallable('scanPass', options: any(named: 'options')),
      );
      verify(() => callable.call<Object?>({'code': '7F3K2QAB'}));
      expect(res.booking, const ScanBooking(id: 'b1', customerName: 'Lan'));
      expect(res.registrations.map((x) => x.kind), [
        ScanKind.entry,
        ScanKind.venueGate,
      ]);
      expect(res.registrations.first.quantity, 3);
      expect(res.waivedCount, 2);
      expect(res.todayCount, 41);
    });

    test('a legacy VE-XXXX-MMDD code goes to the server as typed', () async {
      final r = _MockResult();
      when(() => r.data).thenReturn({'registrations': <Object?>[]});
      when(() => callable.call<Object?>(any())).thenAnswer((_) async => r);
      await repo.scan('ve-ab2c-1020');
      verify(() => callable.call<Object?>({'code': 'VE-AB2C-1020'}));
    });

    test('scan refusals carry their details', () async {
      Future<PassError> refusal(Map<String, Object?> details) async {
        when(() => callable.call<Object?>(any())).thenThrow(
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message: details['code']! as String,
            details: details,
          ),
        );
        try {
          await repo.scan('7F3K2QAB');
        } on PassError catch (e) {
          return e;
        }
        fail('no error');
      }

      final wrong = await refusal({'code': 'wrong_day', 'day': '2026-11-21'});
      expect(wrong.code, PassErrorCode.wrongDay);
      expect(wrong.day, '2026-11-21');
      final early = await refusal({
        'code': 'too_early',
        'opensAt': '2026-11-21T00:00:00.000Z',
      });
      expect(early.code, PassErrorCode.tooEarly);
      expect(early.opensAt, DateTime.parse('2026-11-21T00:00:00Z'));
      final again = await refusal({
        'code': 'already_checked_in',
        'at': '2026-11-21T01:30:00.000Z',
      });
      expect(again.code, PassErrorCode.alreadyCheckedIn);
      expect(again.at, DateTime.parse('2026-11-21T01:30:00Z'));
      expect(
        (await refusal({'code': 'not_your_pass'})).code,
        PassErrorCode.notYourPass,
      );
      expect(
        (await refusal({'code': 'refunded'})).code,
        PassErrorCode.refunded,
      );
      expect(
        (await refusal({'code': 'not_found'})).code,
        PassErrorCode.notFound,
      );
    });

    test('an unreachable server is a network error', () async {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(code: 'unavailable', message: 'x'),
      );
      expect(
        () => repo.scan('7F3K2QAB'),
        throwsA(
          isA<PassError>().having((e) => e.code, 'code', PassErrorCode.network),
        ),
      );
    });
  });

  group('myPassProvider', () {
    test('myPassProvider caches the code in prefs and serves it when the stream errors', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final passes = FakePassRepository();
      const ref = PassRef.booking('b1');

      final online = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          passRepositoryProvider.overrideWithValue(passes),
        ],
      );
      passes.setBookingPass('b1', '7F3K2QAB');
      final sub = online.listen(myPassProvider(ref), (_, _) {});
      expect(await online.read(myPassProvider(ref).future), '7F3K2QAB');
      expect(prefs.getString('pass.b1'), '7F3K2QAB');
      sub.close();
      online.dispose();

      // Offline: the stream fails, the cached code still draws the QR.
      passes.failWith = StateError('offline');
      final offline = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          passRepositoryProvider.overrideWithValue(passes),
        ],
      );
      addTearDown(offline.dispose);
      final values = <AsyncValue<String?>>[];
      offline.listen(
        myPassProvider(ref),
        (_, next) => values.add(next),
        fireImmediately: true,
      );
      await pumpEventQueue();
      expect(values.last.hasError, isFalse);
      expect(values.last.value, '7F3K2QAB');
    });

    test('without a cached code the error comes through', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final passes = FakePassRepository()..failWith = StateError('offline');
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          passRepositoryProvider.overrideWithValue(passes),
        ],
      );
      addTearDown(c.dispose);
      const ref = PassRef.registration('e1', 'r1');
      c.listen(myPassProvider(ref), (_, _) {});
      await pumpEventQueue();
      expect(c.read(myPassProvider(ref)).hasError, isTrue);
    });

    test('a pass that is gone clears the cache', () async {
      SharedPreferences.setMockInitialValues({'pass.r1': '7F3K2QAB'});
      final prefs = await SharedPreferences.getInstance();
      final passes = FakePassRepository();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          passRepositoryProvider.overrideWithValue(passes),
        ],
      );
      addTearDown(c.dispose);
      const ref = PassRef.registration('e1', 'r1');
      c.listen(myPassProvider(ref), (_, _) {});
      await pumpEventQueue();
      expect(c.read(myPassProvider(ref)).value, isNull);
      expect(prefs.getString('pass.r1'), isNull);
    });
  });
}
