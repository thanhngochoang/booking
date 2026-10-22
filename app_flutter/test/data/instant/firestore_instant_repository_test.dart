import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/firestore_instant_repository.dart';
import 'package:photobooking/data/instant/instant_models.dart';

/// Records every callable call and answers from [answers] (or throws [error]).
class _Calls {
  final calls = <({String name, Map<String, Object?> data})>[];
  final answers = <String, Object?>{};
  Object? error;

  Future<Object?> call(String name, Map<String, Object?> data) async {
    calls.add((name: name, data: data));
    final e = error;
    if (e != null) throw e;
    return answers[name];
  }
}

Timestamp _ts(int h, [int m = 0, int s = 0]) =>
    Timestamp.fromDate(DateTime.utc(2026, 10, 22, h, m, s));

Map<String, dynamic> _offer(
  Timestamp expiresAt, {
  String outcome = 'pending',
}) => {
  'requestId': 'req1',
  'photographerId': 'ph1',
  'round': 1,
  'offeredAt': _ts(8),
  'expiresAt': expiresAt,
  'outcome': outcome,
  'packageCode': 'p60',
  'durationMin': 60,
  'photos': 30,
  'genre': 'portrait',
  'areaLabel': 'Quận 1, TP.HCM',
  'distanceKm': 2.1,
  'etaMinutes': 9,
  'earningVnd': 690000,
  'note': '',
  'invitedCount': 2,
};

void main() {
  late FakeFirebaseFirestore db;
  late _Calls fn;

  FirestoreInstantRepository repo({String? uid = 'cus1'}) =>
      FirestoreInstantRepository(firestore: db, uid: uid, callable: fn.call);

  setUp(() {
    db = FakeFirebaseFirestore();
    fn = _Calls();
  });

  group('callables', () {
    test('createRequest sends the exact payload', () async {
      fn.answers['createInstantRequest'] = {
        'requestId': 'req9',
        'amountVnd': 690000,
        'round': 1,
        'candidateCount': 3,
      };
      final id = await repo().createRequest(
        packageCode: 'p60',
        genre: InstantGenre.couple,
        lat: 10.7769,
        lng: 106.6923,
        meetPointName: 'Cổng Trương Định',
        note: 'Cầu hôn',
      );
      expect(id, 'req9');
      expect(fn.calls.single.name, 'createInstantRequest');
      expect(fn.calls.single.data, {
        'packageCode': 'p60',
        'genre': 'couple',
        'meetPoint': {
          'lat': 10.7769,
          'lng': 106.6923,
          'name': 'Cổng Trương Định',
        },
        'note': 'Cầu hôn',
      });

      await repo().createRequest(
        packageCode: 'p30',
        genre: InstantGenre.event,
        lat: 1,
        lng: 2,
        meetPointName: 'X',
      );
      expect(fn.calls.last.data.containsKey('note'), isFalse);
      expect(fn.calls.last.data['genre'], 'event');
    });

    test(
      'invite parses invited and price_changed results and sends no payMethod',
      () async {
        fn.answers['inviteInstant'] = {
          'kind': 'invited',
          'invited': ['ph1', 'ph2'],
          'unavailable': ['ph3'],
        };
        final r = await repo().invite(
          'req1',
          photographerIds: ['ph1', 'ph2', 'ph3'],
          skipped: ['ph9'],
          expectedAmountVnd: 690000,
        );
        expect(r, isA<InstantInvited>());
        expect((r as InstantInvited).invited, ['ph1', 'ph2']);
        expect(r.unavailable, ['ph3']);
        expect(fn.calls.single.name, 'inviteInstant');
        expect(fn.calls.single.data, {
          'requestId': 'req1',
          'photographerIds': ['ph1', 'ph2', 'ph3'],
          'skipped': ['ph9'],
          'expectedAmountVnd': 690000,
        });
        expect(fn.calls.single.data.containsKey('payMethod'), isFalse);

        fn.answers['inviteInstant'] = {
          'kind': 'price_changed',
          'amountVnd': 720000,
        };
        final changed = await repo().invite(
          'req1',
          photographerIds: ['ph1'],
          skipped: const [],
          expectedAmountVnd: 690000,
        );
        expect(changed, isA<InstantPriceChanged>());
        expect((changed as InstantPriceChanged).amountVnd, 720000);

        // A kind this build does not know (#202's `payment`) is not silently dropped.
        fn.answers['inviteInstant'] = {'kind': 'payment', 'amountVnd': 1};
        await expectLater(
          repo().invite(
            'req1',
            photographerIds: ['ph1'],
            skipped: const [],
            expectedAmountVnd: 1,
          ),
          throwsA(isA<InstantError>().having((e) => e.code, 'code', 'unknown')),
        );
      },
    );

    test('a FirebaseFunctionsException with details.code becomes InstantError(code)', () async {
      fn.error = FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'something human',
        details: {'code': 'already_assigned'},
      );
      await expectLater(
        repo(uid: 'ph1').answerOffer('of1', accept: true),
        throwsA(
          isA<InstantError>()
              .having((e) => e.code, 'code', 'already_assigned')
              .having((e) => e.kind, 'kind', InstantErrorKind.alreadyAssigned),
        ),
      );
      expect(fn.calls.single.data, {'offerId': 'of1', 'action': 'accept'});

      // Without details.code the transport code decides; never the message.
      fn.error = FirebaseFunctionsException(
        code: 'aborted',
        message: 'offer_expired',
      );
      await expectLater(
        repo().tick('req1'),
        throwsA(isA<InstantError>().having((e) => e.code, 'code', 'conflict')),
      );
      fn.error = FirebaseFunctionsException(code: 'internal', message: 'x');
      await expectLater(
        repo().tick('req1'),
        throwsA(isA<InstantError>().having((e) => e.code, 'code', 'unknown')),
      );
    });

    test("unavailable becomes InstantError('network')", () async {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        fn.error = FirebaseFunctionsException(code: code, message: 'down');
        await expectLater(
          repo().cancel('req1', dryRun: true),
          throwsA(
            isA<InstantError>()
                .having((e) => e.code, 'code', 'network')
                .having((e) => e.kind, 'kind', InstantErrorKind.network),
          ),
        );
      }
      expect(instantErrorCodeOf(const InstantError('no_match')), 'no_match');
      expect(instantErrorCodeOf(StateError('x')), 'unknown');
    });

    test('job, settings and Live Shutter payloads and results', () async {
      fn.answers['updateInstantJob'] = {'status': 'arrived'};
      final status = await repo(uid: 'ph1').updateJob(
        'req1',
        InstantJobAction.arrive,
        location: (lat: 10.7, lng: 106.7, accuracyM: 150),
        force: true,
      );
      expect(status, InstantStatus.arrived);
      expect(fn.calls.last.data, {
        'requestId': 'req1',
        'action': 'arrive',
        'location': {'lat': 10.7, 'lng': 106.7, 'accuracyM': 150.0},
        'force': true,
      });

      fn.answers['setLiveShutter'] = {
        'online': false,
        'reasons': ['phone_required', 'price_list_not_accepted'],
      };
      final reasons = await repo(uid: 'ph1')
          .setLiveShutter(online: true, dryRun: true);
      expect(reasons, [
        LiveShutterReason.phoneRequired,
        LiveShutterReason.priceListNotAccepted,
      ]);
      expect(fn.calls.last.data, {'online': true, 'dryRun': true});

      fn.answers['saveInstantSettings'] = {
        'priceListVersion': 1,
        'helpReady': false,
      };
      await repo(uid: 'ph1').saveSettings(acceptPriceListVersion: 1);
      expect(fn.calls.last.data, {'acceptPriceListVersion': 1});

      fn.answers['nextInstantCandidates'] = {
        'round': 2,
        'candidateCount': 4,
        'status': 'choosing',
      };
      await repo().nextCandidates('req1', skipped: ['ph1']);
      expect(fn.calls.last.data, {
        'requestId': 'req1',
        'skipped': ['ph1'],
      });

      fn.answers['cancelInstantRequest'] = {
        'rule': 'unpaid',
        'refundPercent': 0,
        'refundVnd': 0,
        'feeVnd': 0,
        'amountVnd': 0,
        'status': 'choosing',
      };
      final q = await repo().cancel('req1', dryRun: false);
      expect(q.rule, InstantCancelRule.unpaid);
      expect(fn.calls.last.data, {'requestId': 'req1', 'dryRun': false});

      fn.answers['confirmInstantComplete'] = {'status': 'completed'};
      await repo().confirmComplete('req1');
      expect(fn.calls.last.name, 'confirmInstantComplete');
      expect(fn.calls.last.data, {'requestId': 'req1'});
    });
  });

  group('direct writes', () {
    test('heartbeat writes only the six position fields', () async {
      final before = {
        'online': true,
        'helpReady': true,
        'priceListVersion': 1,
        'cityId': 'hcm',
        'lat': 10.0,
        'lng': 106.0,
        'accuracyM': 50.0,
        'geohash5': 'w21z7',
        'geohash4': 'w21z',
        'heartbeatAt': _ts(7),
        'activeRequestId': null,
        'pendingOffers': <Object>[],
        'profile': {'name': 'Minh'},
        'reliability': {'offers': 3},
        'updatedAt': _ts(7),
      };
      await db.doc('instant_presence/ph1').set(before);

      await repo(uid: 'ph1')
          .heartbeat(lat: 10.7769, lng: 106.7009, accuracyM: 35);

      final after = (await db.doc('instant_presence/ph1').get()).data()!;
      final changed = {
        for (final k in {...before.keys, ...after.keys})
          if (!_same(before[k], after[k])) k,
      };
      expect(changed, {
        'lat',
        'lng',
        'accuracyM',
        'geohash5',
        'geohash4',
        'heartbeatAt',
      });
      expect(after['lat'], 10.7769);
      expect(after['lng'], 106.7009);
      expect(after['accuracyM'], 35.0);
      expect(after['geohash5'], encodeGeohash(10.7769, 106.7009, precision: 5));
      expect(after['geohash4'], (after['geohash5'] as String).substring(0, 4));
      expect(after['heartbeatAt'], isA<Timestamp>());
    });

    test('shareTrack writes only lat/lng/accuracyM/heading/at', () async {
      final before = {
        'customerId': 'cus1',
        'photographerId': 'ph1',
        'active': true,
        'lat': 10.0,
        'lng': 106.0,
        'accuracyM': 20.0,
        'heading': null,
        'at': _ts(8),
      };
      await db.doc('instant_tracks/req1').set(before);

      await repo(
        uid: 'ph1',
      ).shareTrack('req1', lat: 10.78, lng: 106.69, accuracyM: 8, heading: 270);

      final after = (await db.doc('instant_tracks/req1').get()).data()!;
      final changed = {
        for (final k in {...before.keys, ...after.keys})
          if (!_same(before[k], after[k])) k,
      };
      expect(changed, {'lat', 'lng', 'accuracyM', 'heading', 'at'});
      expect(after.keys.toSet(), before.keys.toSet());
      expect(after['heading'], 270.0);
      expect(after['at'], isA<Timestamp>());
    });

    test('signed out: no direct write is attempted', () async {
      await expectLater(
        repo(uid: null).heartbeat(lat: 1, lng: 2, accuracyM: 3),
        throwsA(
          isA<InstantError>().having(
            (e) => e.code,
            'code',
            'permission_denied',
          ),
        ),
      );
    });
  });

  group('reads', () {
    test('watchPendingOffers sorts by expiresAt', () async {
      final offers = db.collection('instant_offers/ph1/offers');
      await offers.doc('late').set(_offer(_ts(8, 3)));
      await offers.doc('early').set(_offer(_ts(8, 1)));
      await offers.doc('mid').set(_offer(_ts(8, 2)));
      await offers.doc('done').set(_offer(_ts(8, 0, 30), outcome: 'declined'));
      await db
          .collection('instant_offers/ph2/offers')
          .doc('other')
          .set(_offer(_ts(8)));

      final list = await repo(uid: 'ph1').watchPendingOffers().first;
      expect(list.map((o) => o.id), ['early', 'mid', 'late']);
      expect(await repo(uid: null).watchPendingOffers().first, isEmpty);
    });

    test('myActiveRequestId returns null when none', () async {
      expect(await repo().myActiveRequestId(), isNull);
      await db.doc('instant_requests/old').set({
        'customerId': 'cus1',
        'active': false,
      });
      await db.doc('instant_requests/theirs').set({
        'customerId': 'cus2',
        'active': true,
      });
      expect(await repo().myActiveRequestId(), isNull);
      await db.doc('instant_requests/mine').set({
        'customerId': 'cus1',
        'active': true,
      });
      expect(await repo().myActiveRequestId(), 'mine');
      expect(await repo(uid: null).myActiveRequestId(), isNull);
    });

    test(
      'watchMyActiveJob and watchPresence follow the signed-in photographer',
      () async {
        await db.doc('instant_requests/job').set({
          'customerId': 'cus1',
          'photographerId': 'ph1',
          'active': true,
          'status': 'assigned',
          'genre': 'portrait',
          'meetPoint': {'lat': 1, 'lng': 2, 'name': 'X'},
        });
        final job = await repo(uid: 'ph1').watchMyActiveJob().first;
        expect(job!.id, 'job');
        expect(job.status, InstantStatus.assigned);
        expect(await repo(uid: 'ph2').watchMyActiveJob().first, isNull);

        expect(await repo(uid: 'ph1').watchPresence().first, isNull);
        await db.doc('instant_presence/ph1').set({
          'online': true,
          'heartbeatAt': _ts(8),
        });
        expect((await repo(uid: 'ph1').watchPresence().first)!.online, isTrue);
      },
    );

    test('a missing config is not_eligible', () async {
      await expectLater(
        repo().config(),
        throwsA(
          isA<InstantError>().having((e) => e.code, 'code', 'not_eligible'),
        ),
      );
    });
  });

  group('error codes and timeouts', () {
    test('contended callables wait 40 s, the others 15 s', () {
      for (final name in [
        'inviteInstant',
        'answerInstantOffer',
        'cancelInstantRequest',
        'confirmInstantComplete',
      ]) {
        expect(instantCallableTimeout(name), const Duration(seconds: 40));
      }
      for (final name in [
        'createInstantRequest',
        'nextInstantCandidates',
        'tickInstantRequest',
        'setLiveShutter',
        'saveInstantSettings',
        'updateInstantJob',
      ]) {
        expect(instantCallableTimeout(name), const Duration(seconds: 15));
      }
    });

    test('transport and write codes map to InstantError codes', () {
      expect(instantTransportErrorCode('unavailable'), 'network');
      expect(instantTransportErrorCode('deadline-exceeded'), 'network');
      expect(instantTransportErrorCode('unauthenticated'), 'permission_denied');
      expect(
        instantTransportErrorCode('permission-denied'),
        'permission_denied',
      );
      expect(instantTransportErrorCode('not-found'), 'not_found');
      expect(instantTransportErrorCode('invalid-argument'), 'invalid_argument');
      expect(instantTransportErrorCode('aborted'), 'conflict');
      expect(instantTransportErrorCode('internal'), 'unknown');

      expect(instantWriteErrorCode('permission-denied'), 'permission_denied');
      expect(instantWriteErrorCode('not-found'), 'not_found');
      expect(instantWriteErrorCode('unavailable'), 'network');
      expect(instantWriteErrorCode('deadline-exceeded'), 'network');
      expect(instantWriteErrorCode('resource-exhausted'), 'unknown');
    });

    test(
      'a direct write that fails in Firestore becomes an InstantError',
      () async {
        // No presence document yet: the update is refused with not-found.
        await expectLater(
          repo(uid: 'ph1').heartbeat(lat: 10.7, lng: 106.7, accuracyM: 20),
          throwsA(
            isA<InstantError>().having((e) => e.code, 'code', 'not_found'),
          ),
        );
      },
    );
  });

  group('nullWhenDenied', () {
    test(
      'permission-denied ends the stream with null; other errors surface',
      () async {
        final logs = <String?>[];
        final print = debugPrint;
        debugPrint = (m, {wrapWidth}) => logs.add(m);
        addTearDown(() => debugPrint = print);
        final denied = StreamController<int?>();
        final out = <int?>[];
        final done = Completer<void>();
        nullWhenDenied(
          denied.stream,
          label: 'instant_tracks',
        ).listen(out.add, onDone: done.complete);
        denied
          ..add(1)
          ..addError(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          );
        await done.future;
        expect(out, [1, null]);
        expect(logs, ['instant_tracks: read denied, reading as absent']);

        final failing = StreamController<int?>();
        final errors = <Object>[];
        nullWhenDenied(failing.stream).listen((_) {}, onError: errors.add);
        failing.addError(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        );
        await Future<void>.delayed(Duration.zero);
        expect(errors.single, isA<FirebaseException>());
        await failing.close();
        await denied.close();
      },
    );
  });

  group('settledPendingOffers', () {
    final o = InstantOffer(
      id: 'o1',
      requestId: 'req1',
      offeredAt: DateTime.utc(2026, 10, 22, 8),
      expiresAt: DateTime.utc(2026, 10, 22, 8, 1),
      outcome: OfferOutcome.pending,
      genre: InstantGenre.portrait,
    );

    Future<List<List<String>>> run(
      List<({List<InstantOffer> offers, bool fromCache})> snaps,
    ) =>
        settledPendingOffers(Stream.fromIterable(snaps))
            .map((l) => [for (final x in l) x.id])
            .toList();

    test(
      'an empty cached list before the server answers is held back',
      () async {
        expect(
          await run([
            (offers: const [], fromCache: true),
            (offers: [o], fromCache: false),
          ]),
          [
            ['o1'],
          ],
        );
      },
    );

    test('after the server answered, an empty list passes', () async {
      expect(
        await run([
          (offers: [o], fromCache: false),
          (offers: const [], fromCache: true),
        ]),
        [
          ['o1'],
          <String>[],
        ],
      );
    });

    test('a non-empty cached list passes (offline)', () async {
      expect(
        await run([
          (offers: [o], fromCache: true),
        ]),
        [
          ['o1'],
        ],
      );
    });

    test('a metadata-only change is not repeated', () async {
      expect(
        await run([
          (offers: [o], fromCache: true),
          (offers: [o], fromCache: false),
          (offers: const [], fromCache: false),
          (offers: const [], fromCache: false),
        ]),
        [
          ['o1'],
          <String>[],
        ],
      );
    });
  });
}

bool _same(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length && a.keys.every((k) => _same(a[k], b[k]));
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_same(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
