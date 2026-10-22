import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/firestore_instant_mapping.dart';
import 'package:photobooking/data/instant/firestore_instant_repository.dart';
import 'package:photobooking/data/instant/instant_models.dart';

Timestamp _ts(int h, [int m = 0, int s = 0]) =>
    Timestamp.fromDate(DateTime.utc(2026, 10, 22, h, m, s));

/// Every field the server's `instantRequestToFirestore` writes, with values.
Map<String, dynamic> fullRequestDoc() => {
  'customerId': 'cus1',
  'customerName': 'Lan Anh',
  'customerAvatarUrl': 'https://img/lan.jpg',
  'status': 'en_route',
  'active': true,
  'packageCode': 'p60',
  'durationMin': 60,
  'photos': 30,
  'genre': 'portrait',
  'note': 'Áo trắng',
  'cityId': 'hcm',
  'meetPoint': {'lat': 10.7769, 'lng': 106.6923, 'name': 'Cổng Trương Định'},
  'areaLabel': 'Quận 1, TP.HCM',
  'amountVnd': 690000,
  'earningVnd': 690000,
  'priceListVersion': 1,
  'platformFeeBp': 0,
  'arrivedCancelPhotographerPercent': 50,
  'committedAt': _ts(8),
  'payMethod': 'momo',
  'provider': null,
  'paymentId': null,
  'paidAt': _ts(8, 1),
  'paymentDeadlineAt': _ts(8, 15),
  'refundId': null,
  'refundStatus': null,
  'round': 2,
  'invitedTotal': 4,
  'roundsWithInvites': 2,
  'candidates': [
    {
      'photographerId': 'ph1',
      'name': 'Minh',
      'avatarUrl': null,
      'verified': true,
      'providerType': 'freelancer',
      'tomatoPct': 96,
      'reviewCount': 12,
      'completedCount': 30,
      'distanceKm': 2.1,
      'etaMinutes': 9,
      'photos': ['a.jpg', 'b.jpg'],
      'reasons': [
        {'code': 'genre', 'text': 'Chụp chân dung'},
        {'code': 'distance', 'text': 'Cách 2,1 km'},
        {'code': 'vip', 'text': 'Not a server code'},
      ],
      'tier': 'priority',
      'score': 0.8,
    },
  ],
  'offers': [
    {
      'offerId': 'of1',
      'photographerId': 'ph1',
      'name': 'Minh',
      'avatarUrl': null,
      'tomatoPct': 96,
      'reviewCount': 12,
      'etaMinutes': 9,
      'outcome': 'accepted',
      'expiresAt': _ts(8, 2),
    },
    {
      'offerId': null,
      'photographerId': 'ph2',
      'name': 'Hà',
      'avatarUrl': 'https://img/ha.jpg',
      'tomatoPct': 0,
      'reviewCount': 0,
      'etaMinutes': 4,
      'outcome': 'unavailable',
      'expiresAt': null,
    },
  ],
  'pendingInviteIds': <String>[],
  'roundEnded': false,
  'photographerId': 'ph1',
  'photographer': {
    'id': 'ph1',
    'name': 'Minh',
    'avatarUrl': 'https://img/minh.jpg',
    'verified': true,
    'tomatoPct': 96,
    'reviewCount': 12,
    'completedCount': 30,
  },
  'chatId': 'chat_cus1_ph1',
  'etaMinutes': 9,
  'assignedAt': _ts(8, 2),
  'freeCancelUntil': _ts(8, 4),
  'lateDeadlineAt': _ts(8, 26),
  'startedRouteAt': _ts(8, 3),
  'arrivedAt': _ts(8, 20),
  'forcedArrivalAccuracyM': null,
  'startedAt': _ts(8, 21),
  'shootEndsAt': _ts(9, 21),
  'finishedAt': _ts(9, 20),
  'completedAt': _ts(9, 30),
  'cancelledAt': _ts(9, 40),
  'cancelledBy': 'photographer',
  'cancelRule': 'arrived',
  'refundPercent': 50,
  'feeVnd': 345000,
  'searchDeadlineAt': _ts(8, 10),
  'lastActivityAt': _ts(8, 3),
  'nextDeadlineAt': null,
  'createdAt': _ts(7, 59),
  'updatedAt': _ts(8, 3),
  'version': 7,
};

Map<String, dynamic> offerDoc({
  String outcome = 'pending',
  Timestamp? expiresAt,
}) => {
  'requestId': 'req1',
  'photographerId': 'ph1',
  'round': 1,
  'offeredAt': _ts(8),
  'expiresAt': expiresAt ?? _ts(8, 1),
  'outcome': outcome,
  'decidedAt': null,
  'packageCode': 'p60',
  'durationMin': 60,
  'photos': 30,
  'genre': 'couple',
  'areaLabel': 'Quận 1, TP.HCM',
  'distanceKm': 2.1,
  'etaMinutes': 9,
  'earningVnd': 552000,
  'note': 'Cầu hôn',
  'invitedCount': 3,
};

void main() {
  group('request', () {
    test('request maps every field, Timestamps to UTC', () {
      final r = instantRequestFromFirestore('req1', fullRequestDoc())!;
      expect(r.id, 'req1');
      expect(r.customerId, 'cus1');
      expect(r.customerName, 'Lan Anh');
      expect(r.customerAvatarUrl, 'https://img/lan.jpg');
      expect(r.status, InstantStatus.enRoute);
      expect(r.status.isActive, isTrue);
      expect(r.packageCode, 'p60');
      expect(r.durationMin, 60);
      expect(r.photos, 30);
      expect(r.genre, InstantGenre.portrait);
      expect(r.note, 'Áo trắng');
      expect(r.meetPoint.lat, 10.7769);
      expect(r.meetPoint.lng, 106.6923);
      expect(r.meetPoint.name, 'Cổng Trương Định');
      expect(r.areaLabel, 'Quận 1, TP.HCM');
      expect(r.amountVnd, 690000);
      expect(r.earningVnd, 690000);
      expect(r.platformFeeBp, 0);
      expect(r.arrivedCancelPhotographerPercent, 50);
      expect(r.payMethod, PayMethod.momo);
      expect(r.paid, isTrue);
      expect(r.committed, isTrue);
      expect(r.round, 2);
      expect(r.invitedTotal, 4);
      expect(r.roundsWithInvites, 2);
      expect(r.roundEnded, isFalse);

      final c = r.candidates.single;
      expect(c.photographerId, 'ph1');
      expect(c.name, 'Minh');
      expect(c.avatarUrl, isNull);
      expect(c.verified, isTrue);
      expect(c.tomatoPct, 96);
      expect(c.reviewCount, 12);
      expect(c.completedCount, 30);
      expect(c.distanceKm, 2.1);
      expect(c.etaMinutes, 9);
      expect(c.photos, ['a.jpg', 'b.jpg']);
      expect(c.reasons, ['Chụp chân dung', 'Cách 2,1 km']);

      expect(r.offers, hasLength(2));
      expect(r.offers.first.photographerId, 'ph1');
      expect(r.offers.first.outcome, OfferOutcome.accepted);
      expect(r.offers.first.expiresAt, DateTime.utc(2026, 10, 22, 8, 2));
      expect(r.offers.first.expiresAt!.isUtc, isTrue);
      expect(r.offers.last.outcome, OfferOutcome.unavailable);
      expect(r.offers.last.expiresAt, isNull);
      expect(r.offers.last.avatarUrl, 'https://img/ha.jpg');

      expect(r.photographerId, 'ph1');
      expect(r.photographer!.id, 'ph1');
      expect(r.photographer!.name, 'Minh');
      expect(r.photographer!.avatarUrl, 'https://img/minh.jpg');
      expect(r.photographer!.verified, isTrue);
      expect(r.photographer!.tomatoPct, 96);
      expect(r.photographer!.reviewCount, 12);
      expect(r.photographer!.completedCount, 30);
      expect(r.chatId, 'chat_cus1_ph1');
      expect(r.etaMinutes, 9);

      final instants = {
        r.assignedAt: DateTime.utc(2026, 10, 22, 8, 2),
        r.freeCancelUntil: DateTime.utc(2026, 10, 22, 8, 4),
        r.lateDeadlineAt: DateTime.utc(2026, 10, 22, 8, 26),
        r.startedRouteAt: DateTime.utc(2026, 10, 22, 8, 3),
        r.arrivedAt: DateTime.utc(2026, 10, 22, 8, 20),
        r.startedAt: DateTime.utc(2026, 10, 22, 8, 21),
        r.shootEndsAt: DateTime.utc(2026, 10, 22, 9, 21),
        r.finishedAt: DateTime.utc(2026, 10, 22, 9, 20),
        r.completedAt: DateTime.utc(2026, 10, 22, 9, 30),
        r.cancelledAt: DateTime.utc(2026, 10, 22, 9, 40),
        r.searchDeadlineAt: DateTime.utc(2026, 10, 22, 8, 10),
        r.paymentDeadlineAt: DateTime.utc(2026, 10, 22, 8, 15),
      };
      for (final e in instants.entries) {
        expect(e.key, e.value);
        expect(e.key!.isUtc, isTrue);
      }
      expect(r.cancelledBy, InstantParticipant.photographer);
      expect(r.cancelRule, InstantCancelRule.arrived);
      expect(r.refundPercent, 50);
      expect(r.feeVnd, 345000);
    });

    test('unknown status maps to null and the stream yields null', () async {
      final doc = {...fullRequestDoc(), 'status': 'disputed'};
      expect(instantRequestFromFirestore('req1', doc), isNull);
      expect(
        instantRequestFromFirestore('req1', {
          ...fullRequestDoc(),
          'genre': 'x',
        }),
        isNull,
      );

      final db = FakeFirebaseFirestore();
      await db.doc('instant_requests/req1').set(doc);
      final repo = FirestoreInstantRepository(
        firestore: db,
        uid: 'cus1',
        callable: (_, _) async => null,
      );
      expect(await repo.watchRequest('req1').first, isNull);
    });

    test(
      'missing optional fields default (no candidates, no photographer)',
      () {
        final r = instantRequestFromFirestore('req2', {
          'customerId': 'cus1',
          'status': 'choosing',
          'genre': 'family',
          'packageCode': 'p30',
          'meetPoint': {'lat': 10.7, 'lng': 106.7, 'name': 'Hồ Con Rùa'},
          'amountVnd': 390000,
          'createdAt': _ts(8),
        })!;
        expect(r.status, InstantStatus.choosing);
        expect(r.arrivedCancelPhotographerPercent, 0);
        expect(r.candidates, isEmpty);
        expect(r.offers, isEmpty);
        expect(r.photographerId, isNull);
        expect(r.photographer, isNull);
        expect(r.chatId, isNull);
        expect(r.etaMinutes, isNull);
        expect(r.paid, isFalse);
        expect(r.committed, isFalse);
        expect(r.payMethod, isNull);
        expect(r.round, 1);
        expect(r.note, '');
        expect(r.customerName, '');
        expect(r.customerAvatarUrl, isNull);
        expect(r.cancelledBy, isNull);
        expect(r.cancelRule, isNull);
        expect(r.refundPercent, isNull);
        expect(r.assignedAt, isNull);
        expect(r.searchDeadlineAt, isNull);
      },
    );
  });

  group('offer', () {
    test('offer rows with unknown outcome read as expired', () {
      final doc = fullRequestDoc();
      (doc['offers'] as List)[0] = {
        ...((doc['offers'] as List)[0] as Map<String, dynamic>),
        'outcome': 'mystery',
      };
      final r = instantRequestFromFirestore('req1', doc)!;
      expect(r.offers.first.outcome, OfferOutcome.expired);
      expect(OfferOutcome.fromCode(null), OfferOutcome.expired);
      expect(OfferOutcome.fromCode('withdrawn'), OfferOutcome.withdrawn);
    });

    test('offer maps areaLabel, distanceKm, earningVnd', () {
      final o = instantOfferFromFirestore('of1', offerDoc())!;
      expect(o.id, 'of1');
      expect(o.requestId, 'req1');
      expect(o.round, 1);
      expect(o.offeredAt, DateTime.utc(2026, 10, 22, 8));
      expect(o.expiresAt, DateTime.utc(2026, 10, 22, 8, 1));
      expect(o.expiresAt.isUtc, isTrue);
      expect(o.outcome, OfferOutcome.pending);
      expect(o.packageCode, 'p60');
      expect(o.durationMin, 60);
      expect(o.photos, 30);
      expect(o.genre, InstantGenre.couple);
      expect(o.areaLabel, 'Quận 1, TP.HCM');
      expect(o.distanceKm, 2.1);
      expect(o.etaMinutes, 9);
      expect(o.earningVnd, 552000);
      expect(o.note, 'Cầu hôn');
      expect(o.invitedCount, 3);
    });

    test('an offer without expiresAt or with an unknown genre is dropped', () {
      expect(
        instantOfferFromFirestore('of1', {...offerDoc(), 'expiresAt': null}),
        isNull,
      );
      expect(
        instantOfferFromFirestore('of1', {...offerDoc(), 'genre': 'x'}),
        isNull,
      );
      expect(instantOfferFromFirestore('of1', null), isNull);
    });
  });

  group('presence', () {
    test('presence fresh is false 30 minutes after heartbeat', () {
      final p = liveShutterStateFromFirestore({
        'online': true,
        'helpReady': true,
        'priceListVersion': 1,
        'heartbeatAt': _ts(8),
        'activeRequestId': 'req1',
        'lat': 10.7,
        'lng': 106.7,
      })!;
      expect(p.online, isTrue);
      expect(p.helpReady, isTrue);
      expect(p.priceListVersion, 1);
      expect(p.activeRequestId, 'req1');
      expect(p.heartbeatAt, DateTime.utc(2026, 10, 22, 8));
      expect(p.fresh(DateTime.utc(2026, 10, 22, 8, 29, 59)), isTrue);
      expect(p.fresh(DateTime.utc(2026, 10, 22, 8, 30)), isFalse);
      final offline = p.copyWith(online: false);
      expect(offline.fresh(DateTime.utc(2026, 10, 22, 8, 1)), isFalse);
      final never = liveShutterStateFromFirestore({'online': true})!;
      expect(never.fresh(DateTime.utc(2026, 10, 22, 8)), isFalse);
      expect(never.priceListVersion, isNull);
    });
  });

  group('config', () {
    Map<String, dynamic> configDoc({int feeBp = 0}) => {
      'enabled': true,
      'priceListVersion': 3,
      'platformFeeBp': feeBp,
      'instantArrivedCancelPhotographerPercent': 40,
      'packages': [
        {'code': 'p30', 'durationMin': 30, 'photos': 15, 'priceVnd': 390000},
        {'code': 'p60', 'durationMin': 60, 'photos': 30, 'priceVnd': 690000},
      ],
      'cities': [
        {
          'id': 'hcm',
          'name': 'TP.HCM',
          'south': 10.35,
          'west': 106.36,
          'north': 11.17,
          'east': 107.03,
          'surgeBp': 10000,
        },
        {
          'id': 'hn',
          'name': 'Hà Nội',
          'south': 20.56,
          'west': 105.28,
          'north': 21.39,
          'east': 106.02,
          'surgeBp': 10000,
        },
      ],
      'areas': [
        {'name': 'Quận 1, TP.HCM', 'lat': 10.7769, 'lng': 106.7009},
      ],
    };

    test(
      'config earningOf is amount − round(amount × platformFeeBp / 10000)',
      () {
        expect(
          instantConfigFromFirestore(configDoc())!.earningOf(690000),
          690000,
        );
        final cfg = instantConfigFromFirestore(configDoc(feeBp: 1250))!;
        // 690000 × 0.125 = 86250 → 603750.
        expect(cfg.earningOf(690000), 603750);
        // 333 × 0.015 = 4.995 → rounds to 5.
        expect(
          instantConfigFromFirestore(configDoc(feeBp: 150))!.earningOf(333),
          328,
        );
        expect(cfg.packages.map((p) => p.code), ['p30', 'p60']);
        expect(cfg.packages.first.priceVnd, 390000);
        expect(cfg.cityNames, ['TP.HCM', 'Hà Nội']);
        expect(cfg.enabled, isTrue);
        expect(cfg.priceListVersion, 3);
      },
    );

    test('config reads instantArrivedCancelPhotographerPercent', () {
      final cfg = instantConfigFromFirestore(configDoc())!;
      expect(cfg.instantArrivedCancelPhotographerPercent, 40);
      expect(instantConfigFromFirestore(null), isNull);
    });

    test('a config the server would refuse reads as absent (parseInstantConfig parity)', () {
      Map<String, dynamic> without(String key) => configDoc()..remove(key);
      Map<String, dynamic> withValue(String key, Object? v) =>
          configDoc()..[key] = v;
      final city =
          (configDoc()['cities'] as List).first as Map<String, dynamic>;
      final refused = <String, Map<String, dynamic>>{
        'no priceListVersion': without('priceListVersion'),
        'priceListVersion 0': withValue('priceListVersion', 0),
        'no enabled': without('enabled'),
        'no platformFeeBp': without('platformFeeBp'),
        'fee over 10000': withValue('platformFeeBp', 10001),
        'split over 100': withValue(
          'instantArrivedCancelPhotographerPercent',
          101,
        ),
        'fractional split': withValue(
          'instantArrivedCancelPhotographerPercent',
          40.5,
        ),
        'one malformed package': withValue('packages', [
          {'code': 'p30', 'durationMin': 30, 'photos': 15, 'priceVnd': 390000},
          {'code': 'bad'},
        ]),
        'no packages': withValue('packages', <Object>[]),
        'duplicate package codes': withValue('packages', [
          {'code': 'p30', 'durationMin': 30, 'photos': 15, 'priceVnd': 390000},
          {'code': 'p30', 'durationMin': 60, 'photos': 30, 'priceVnd': 690000},
        ]),
        'no cities': withValue('cities', <Object>[]),
        'city box inverted': withValue('cities', [
          {...city, 'south': 12.0},
        ]),
        'city without surge': withValue('cities', [
          {...city}..remove('surgeBp'),
        ]),
        'no areas': without('areas'),
        'malformed area': withValue('areas', [
          {'name': 'X', 'lat': 100, 'lng': 0},
        ]),
      };
      for (final e in refused.entries) {
        expect(instantConfigFromFirestore(e.value), isNull, reason: e.key);
      }
      // A whole double is an integer, as Number.isInteger says.
      expect(
        instantConfigFromFirestore(withValue('priceListVersion', 3.0))!
            .priceListVersion,
        3,
      );
    });
  });

  group('callable results', () {
    test('cancel quote and track parse', () {
      final q = instantCancelQuoteFromJson({
        'rule': 'en_route',
        'refundPercent': 80,
        'refundVnd': 552000,
        'feeVnd': 138000,
        'amountVnd': 690000,
        'status': 'en_route',
      });
      expect(q.rule, InstantCancelRule.enRoute);
      expect(q.refundPercent, 80);
      expect(q.refundVnd, 552000);
      expect(q.feeVnd, 138000);
      expect(q.amountVnd, 690000);

      final t = instantTrackFromFirestore({
        'lat': 10.78,
        'lng': 106.7,
        'accuracyM': 12,
        'heading': 90,
        'at': _ts(8, 5),
        'active': true,
      })!;
      expect(t.lat, 10.78);
      expect(t.accuracyM, 12.0);
      expect(t.at, DateTime.utc(2026, 10, 22, 8, 5));
      expect(instantTrackFromFirestore({'lat': 1}), isNull);
    });
  });
}
