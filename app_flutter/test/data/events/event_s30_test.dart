import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_draft.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/firestore_event_mapping.dart';
import 'package:photobooking/data/events/firestore_event_repository.dart';
import 'package:photobooking/data/events/firestore_nearby_events_repository.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/organizer/organizer.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

Timestamp _ts(String iso) => Timestamp.fromDate(DateTime.parse(iso));

Map<String, dynamic> _event(
  String type, {
  Map<String, dynamic> extra = const {},
}) => {
  'title': 'Sự kiện',
  'type': type,
  'status': 'open',
  'host': {'type': 'organizer', 'id': 'org1', 'name': 'Bãi đá'},
  'createdBy': 'org1',
  'startAt': _ts('2026-11-21T01:00:00Z'),
  'endAt': _ts('2026-11-21T05:00:00Z'),
  'location': {
    'name': 'Bãi đá',
    'lat': 21.0,
    'lng': 105.8,
    'geohash': 'w7er8u0',
  },
  'price': 0,
  'capacity': 20,
  'createdAt': _ts('2026-10-20T00:00:00Z'),
  ...extra,
};

void main() {
  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  group('mapping', () {
    test('entry type and organizer host read as themselves', () {
      final d = eventDetailFromFirestore(
        'e1',
        _event(
          'entry',
          extra: {
            'spotId': 's1',
            'openHours': {'start': '07:00', 'end': '18:00'},
            'ticketTypes': [
              {
                'id': 't1',
                'name': 'Người lớn',
                'price': 70000,
                'hidden': false,
              },
            ],
          },
        ),
      )!;
      expect(d.summary.type, EventType.entry);
      expect(d.summary.hostType, HostType.organizer);
      expect(d.summary.hostId, 'org1');
      expect(d.summary.hostName, 'Bãi đá');
      expect(d.entry!.ticketTypes.single.price, 70000);
      expect(d.isManagedBy('org1', null), isTrue, reason: 'Decision 2');
      expect(EventType.listed, isNot(contains(EventType.entry)));
    });

    test('venue, venue consent and the venue fee map', () {
      final d = eventDetailFromFirestore(
        'e2',
        _event(
          'workshop',
          extra: {
            'venue': {
              'kind': 'managed_spot',
              'spotId': 's1',
              'entryFee': {'included': false, 'amountVnd': 70000},
              'commitmentAt': null,
              'termsVersion': '2026-10-18',
            },
            'venueConsent': 'pending',
            'venueConsentExpiresAt': _ts('2026-10-23T00:00:00Z'),
            'venueFeePerGuest': 20000,
          },
        ),
      )!;
      expect(d.venue!.kind, VenueKind.managedSpot);
      expect(d.venue!.spotId, 's1');
      expect(d.venue!.entryFeeIncluded, isFalse);
      expect(d.venue!.entryFeeVnd, 70000);
      expect(d.venueConsent, HostConsent.pending);
      expect(d.venueConsentExpiresAt, DateTime.parse('2026-10-23T00:00:00Z'));
      expect(d.venueFeePerGuest, 20000);
      expect(d.entry, isNull);

      final old = eventDetailFromFirestore('e3', _event('workshop'))!;
      expect(old.venue, isNull);
      expect(old.venueConsent, HostConsent.notRequired);
      expect(old.venueFeePerGuest, 0);
    });

    test(
      'registration visitDay/items/ticketCodeLast4/bookingId/gateCheckedInAt',
      () {
        final r = registrationFromFirestore('r1', {
          'eventId': 'e1',
          'userId': 'u1',
          'createdAt': _ts('2026-10-20T00:00:00Z'),
          'status': 'paid',
          'quantity': 3,
          'amount': 170000,
          'visitDay': '2026-11-21',
          'items': [
            {
              'ticketTypeId': 't1',
              'name': 'Người lớn',
              'price': 70000,
              'qty': 2,
            },
            {'ticketTypeId': 't2', 'name': 'Trẻ em', 'price': 30000, 'qty': 1},
          ],
          'bookingId': 'b1',
          'gateCheckedInAt': _ts('2026-11-21T02:00:00Z'),
          'ticketCodeLast4': '2QAB',
          'event': {'title': 'Vé vào cửa', 'type': 'entry'},
        })!;
        expect(r.visitDay, '2026-11-21');
        expect(r.items.map((i) => i.qty), [2, 1]);
        expect(r.items.first.name, 'Người lớn');
        expect(r.bookingId, 'b1');
        expect(r.gateCheckedInAt, DateTime.parse('2026-11-21T02:00:00Z'));
        expect(r.ticketCodeLast4, '2QAB');
        expect(r.codeLast4, '2QAB');
        expect(r.isEntry, isTrue);

        final legacy = registrationFromFirestore('r2', {
          'eventId': 'e1',
          'userId': 'u1',
          'createdAt': _ts('2026-10-20T00:00:00Z'),
          'ticketCode': 'VE-AB2C-1020',
        })!;
        expect(legacy.visitDay, isNull);
        expect(legacy.items, isEmpty);
        expect(legacy.codeLast4, '1020');
        expect(legacy.isEntry, isFalse);
      },
    );

    test('EventDraft sends the venue block', () {
      final draft = const EventDraft(title: 'Workshop').copyWith(
        venue: EventVenue(
          kind: VenueKind.publicPlace,
          commitmentAt: DateTime.parse('2026-10-20T00:00:00Z'),
          termsVersion: '2026-10-18',
        ),
      );
      expect(draft.toCallable()['venue'], {
        'kind': 'public',
        'spotId': null,
        'entryFee': {'included': true, 'amountVnd': null},
        'commitmentAt': '2026-10-20T00:00:00.000Z',
        'termsVersion': '2026-10-18',
      });
      final back = EventDraft.fromJson(draft.toJson());
      expect(back.venue, draft.venue);
    });
  });

  group('FirestoreEventRepository', () {
    late FakeFirebaseFirestore db;
    late _MockFunctions functions;
    late _MockCallable callable;
    late FirestoreEventRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      functions = _MockFunctions();
      callable = _MockCallable();
      when(() => functions.httpsCallable(any(), options: any(named: 'options')))
          .thenReturn(callable);
      repo = FirestoreEventRepository(
        uid: 'u1',
        uploader: FakeMediaUploader(),
        db: db,
        functions: functions,
      );
    });

    void answer(Object? data) {
      final r = _MockResult();
      when(() => r.data).thenReturn(data);
      when(() => callable.call<Object?>(any())).thenAnswer((_) async => r);
    }

    void refuse(String code) => when(() => callable.call<Object?>(any()))
        .thenThrow(
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message: code,
            details: {'code': code},
          ),
        );

    test(
      'registerEntry sends {eventId, visitDay, items, name, method}',
      () async {
        answer({
          'registrationId': 'r1',
          'status': 'held',
          'paymentId': 'pay1',
          'instructions': null,
          'holdExpiresAt': '2026-11-01T00:15:00.000Z',
        });
        final out = await repo.registerEntry(
          eventId: 'e1',
          visitDay: '2026-11-21',
          items: const [EntryItem(ticketTypeId: 't1', qty: 2)],
          name: 'Lan',
          method: PayMethod.bankQr,
        );
        verify(
          () => functions.httpsCallable(
            'registerEntry',
            options: any(named: 'options'),
          ),
        );
        verify(
          () => callable.call<Object?>({
            'eventId': 'e1',
            'visitDay': '2026-11-21',
            'items': [
              {'ticketTypeId': 't1', 'qty': 2},
            ],
            'name': 'Lan',
            'method': 'bank_qr',
          }),
        );
        expect(out.registrationId, 'r1');
        expect(out.holdExpiresAt, DateTime.parse('2026-11-01T00:15:00Z'));
      },
    );

    test('registerEntry maps sold_out_day → RegisterRefusal.soldOutDay, day_closed → dayClosed, limit_exceeded → limit', () async {
      Future<RegisterRefusal> refusal(String code) async {
        refuse(code);
        try {
          await repo.registerEntry(
            eventId: 'e1',
            visitDay: '2026-11-21',
            items: const [EntryItem(ticketTypeId: 't1', qty: 11)],
            name: 'Lan',
          );
        } catch (e) {
          return registerRefusalOf(e);
        }
        fail('no error');
      }

      expect(await refusal('sold_out_day'), RegisterRefusal.soldOutDay);
      expect(await refusal('day_closed'), RegisterRefusal.dayClosed);
      expect(await refusal('limit_exceeded'), RegisterRefusal.limit);
      expect(await refusal('phone_required'), RegisterRefusal.phoneRequired);
      expect(await refusal('what'), RegisterRefusal.other);
    });

    test('saveEntryDraft sends type entry and the per-day rules', () async {
      answer({'eventId': 'e1', 'hashtag': ''});
      final id = await repo.saveEntryDraft(
        const EntryEventDraft(
          spotId: 's1',
          title: 'Vé vào cửa Bãi đá',
          startDay: '2026-11-01',
          endDay: '2026-11-30',
          closedWeekdays: [1],
          closedDays: ['2026-11-20'],
          openHours: OpenHours(start: '07:00', end: '18:00'),
          ticketTypes: [
            EntryTicketType(id: 't1', name: 'Người lớn', price: 70000),
            EntryTicketType(id: '', name: 'Trẻ em', price: 30000),
          ],
          dailyCapacity: 200,
        ),
      );
      expect(id, 'e1');
      verify(
        () => functions.httpsCallable(
          'saveEventDraft',
          options: any(named: 'options'),
        ),
      );
      verify(
        () => callable.call<Object?>({
          'type': 'entry',
          'spotId': 's1',
          'title': 'Vé vào cửa Bãi đá',
          'startAt': '2026-11-01',
          'endAt': '2026-11-30',
          'closedWeekdays': [1],
          'closedDays': ['2026-11-20'],
          'openHours': {'start': '07:00', 'end': '18:00'},
          'ticketTypes': [
            {'id': 't1', 'name': 'Người lớn', 'price': 70000, 'hidden': false},
            {'name': 'Trẻ em', 'price': 30000, 'hidden': false},
          ],
          'dailyCapacity': 200,
          'refundCutoffHours': 48,
        }),
      );
    });

    test(
      'updateEntryEvent edits a published entry event through updateEvent',
      () async {
        answer(<String, Object?>{});
        await repo.updateEntryEvent(
          'e1',
          const EntryEventDraft(
            spotId: 's1',
            startDay: '2026-11-01',
            endDay: '2026-11-30',
            openHours: OpenHours(start: '07:00', end: '18:00'),
            ticketTypes: [
              EntryTicketType(id: 't1', name: 'Người lớn', price: 70000),
            ],
          ),
        );
        final payload =
            verify(() => callable.call<Object?>(captureAny())).captured.single
                as Map;
        expect(payload['eventId'], 'e1');
        expect(payload['type'], 'entry');
        verify(
          () => functions.httpsCallable(
            'updateEvent',
            options: any(named: 'options'),
          ),
        );
      },
    );

    test(
      'respondVenueConsent sends {eventId, accept, venueFeePerGuest}',
      () async {
        answer(<String, Object?>{});
        await repo.respondVenueConsent(
          'e2',
          accept: true,
          venueFeePerGuest: 20000,
        );
        verify(
          () => callable.call<Object?>({
            'eventId': 'e2',
            'accept': true,
            'venueFeePerGuest': 20000,
          }),
        );
        await repo.respondVenueConsent('e2', accept: false);
        verify(
          () => callable.call<Object?>({'eventId': 'e2', 'accept': false}),
        );
      },
    );

    test('the public list (S11.01) never shows an entry event', () async {
      final from = DateTime.parse('2026-11-01T00:00:00Z');
      await db.collection('events').doc('w1').set(_event('photo_walk'));
      await db
          .collection('events')
          .doc('e1')
          .set(
            _event('entry', extra: {'startAt': _ts('2026-11-21T03:00:00Z')}),
          );
      await db
          .collection('events')
          .doc('w2')
          .set(
            _event('workshop', extra: {'startAt': _ts('2026-11-22T01:00:00Z')}),
          );
      final page = await repo.list(from: from, limit: 1);
      expect(page.events.map((e) => e.id), ['w1']);
      final next = await repo.list(
        from: from,
        cursor: page.nextCursor,
        limit: 1,
      );
      // The entry row is skipped, never shown, and paging still reaches w2.
      final ids = [...next.events.map((e) => e.id)];
      var cursor = next.nextCursor;
      while (cursor != null) {
        final more = await repo.list(from: from, cursor: cursor, limit: 1);
        ids.addAll(more.events.map((e) => e.id));
        cursor = more.nextCursor;
      }
      expect(ids, ['w2']);
    });
  });

  test('the nearby list never shows an entry event', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('events').doc('w1').set(_event('photo_walk'));
    await db.collection('events').doc('e1').set(_event('entry'));
    final repo = FirestoreNearbyEventsRepository(db: db);
    final out = await repo.inCells([
      'w7er',
    ], from: DateTime.parse('2026-11-01T00:00:00Z'));
    expect(out.map((e) => e.id), ['w1']);
  });

  group('venue requests (S30.03 "Sự kiện ở đây chờ bạn đồng ý")', () {
    Map<String, dynamic> request(
      String spotId, {
      String consent = 'pending',
      String status = 'draft',
      String expires = '2026-11-12T00:00:00Z',
    }) => _event(
      'photo_walk',
      extra: {
        'status': status,
        'host': {'type': 'photographer', 'id': 'p1', 'name': 'Minh Trí'},
        'createdBy': 'p1',
        'venue': {
          'kind': 'managed_spot',
          'spotId': spotId,
          'entryFee': {'included': true, 'amountVnd': null},
          'commitmentAt': null,
          'termsVersion': '2026-10-18',
        },
        'venueConsent': consent,
        'venueConsentExpiresAt': _ts(expires),
      },
    );

    test('Firestore: events where venue.spotId == spot and venueConsent == pending, soonest expiry first', () async {
      final db = FakeFirebaseFirestore();
      await db
          .doc('events/late')
          .set(request('bd', expires: '2026-11-13T00:00:00Z'));
      await db.doc('events/soon').set(request('bd'));
      await db.doc('events/other').set(request('ho-tay'));
      await db.doc('events/done').set(request('bd', consent: 'accepted'));
      final repo = FirestoreEventRepository(
        uid: 'org1',
        uploader: FakeMediaUploader(),
        db: db,
        functions: _MockFunctions(),
      );
      final out = await repo.watchVenueRequests('bd').first;
      expect(out.map((e) => e.id), ['soon', 'late']);
      expect(out.first.venueConsent, HostConsent.pending);
    });

    test('the fake lists the same', () async {
      final repo = FakeEventRepository(uid: 'org1');
      final base = eventDetailFromFirestore('a', request('bd'))!;
      repo
        ..putEvent(base)
        ..putEvent(eventDetailFromFirestore('b', request('ho-tay'))!)
        ..putEvent(
          eventDetailFromFirestore('c', request('bd', consent: 'declined'))!,
        );
      final out = await repo.watchVenueRequests('bd').first;
      expect(out.map((e) => e.id), ['a']);
    });
  });
}
