import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/core/payments.dart';
import 'package:photobooking/data/auth/staff_role.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_draft.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/firestore_event_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';

import '../../support/event_world.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

void main() {
  late FakeFirebaseFirestore db;
  late _MockFunctions functions;
  late _MockCallable callable;
  late FakeMediaUploader uploader;
  late FirestoreEventRepository repo;

  FirestoreEventRepository repoFor(String? uid) => FirestoreEventRepository(
    uid: uid,
    uploader: uploader,
    db: db,
    functions: functions,
  );

  Future<void> seed(String id, Map<String, dynamic> doc) =>
      db.collection('events').doc(id).set(doc);

  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  setUp(() {
    db = FakeFirebaseFirestore();
    functions = _MockFunctions();
    callable = _MockCallable();
    uploader = FakeMediaUploader();
    when(() => functions.httpsCallable(any(), options: any(named: 'options')))
        .thenReturn(callable);
    repo = repoFor('u1');
  });

  void answer(Object? data) {
    final result = _MockResult();
    when(() => result.data).thenReturn(data);
    when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);
  }

  group('parsing', () {
    test(
      'an event doc parses with host, location, counters and hashtag',
      () async {
        await seed(
          'ev1',
          eventDoc(
            registered: 7,
            held: 2,
            faq: [
              {'question': 'Có gửi xe?', 'answer': 'Có'},
            ],
          ),
        );
        final e = (await repo.watchEvent('ev1').first)!;
        final s = e.summary;
        expect(s.title, 'Photo walk phố cổ');
        expect(
          (s.hostType, s.hostId, s.hostName),
          (HostType.photographer, 'p1', 'Quốc Bảo'),
        );
        expect(s.hostVerified, isTrue);
        expect(s.type, EventType.photoWalk);
        expect(s.locationName, 'Công viên Bạch Đằng');
        expect(s.hasGeo, isTrue);
        expect(s.geohash, hasLength(9));
        expect((s.capacity, s.registeredCount, s.heldCount), (20, 7, 2));
        expect(s.seatsLeft, 11);
        expect(s.status, EventStatus.open);
        expect(s.startsAt, eventNow.add(const Duration(days: 3)));
        expect(s.endsAt, eventNow.add(const Duration(days: 3, hours: 2)));
        expect(e.hashtag, 'PhotoWalkPhoCo1013');
        expect(e.meetingPoint, 'Cổng chính');
        expect(e.chatId, 'event_x');
        expect(e.postCount, 2);
        expect(
          e.registrationDeadline,
          eventNow
              .add(const Duration(days: 3))
              .subtract(const Duration(hours: 12)),
        );
        expect(
          e.faq.single,
          const EventFaq(question: 'Có gửi xe?', answer: 'Có'),
        );
      },
    );

    test('a platform event parses with no host id', () async {
      await seed(
        'pl1',
        eventDoc(hostType: 'platform', createdBy: 's1', createdByRole: 'sales'),
      );
      final e = (await repo.watchEvent('pl1').first)!;
      expect(e.summary.hostType, HostType.platform);
      expect(e.summary.hostId, isNull);
      expect(e.summary.hostName, '');
      expect(e.summary.isPlatformHosted, isTrue);
      expect(e.isManagedBy('p1', null), isFalse);
      expect(e.isManagedBy('s1', StaffRole.sales), isTrue);
      expect(e.isManagedBy('s2', StaffRole.sales), isFalse);
      expect(e.isManagedBy('s2', StaffRole.admin), isTrue);
    });

    test('a free event has price 0 and isFree', () async {
      await seed('f1', eventDoc(price: 0));
      final e = (await repo.watchEvent('f1').first)!;
      expect(e.summary.priceVnd, 0);
      expect(e.summary.isFree, isTrue);
    });

    test(
      'a draft without a date still parses and says it has no schedule',
      () async {
        await seed(
          'd1',
          eventDoc(
            status: 'draft',
            schedule: false,
            price: null,
            capacity: null,
          ),
        );
        final e = (await repo.watchEvent('d1').first)!;
        expect(e.summary.hasSchedule, isFalse);
        expect(e.priceSet, isFalse);
        expect(e.capacitySet, isFalse);
        final draft = EventDraft.fromDetail(e);
        expect(draft.startsAt, isNull);
        expect(draft.priceVnd, isNull);
        expect(draft.capacity, isNull);
        expect(draft.place?.name, 'Công viên Bạch Đằng');
      },
    );

    test('a photographer manages their own event, staff by role', () async {
      await seed('ev1', eventDoc());
      final e = (await repo.watchEvent('ev1').first)!;
      expect(e.isManagedBy('p1', null), isTrue);
      expect(e.isManagedBy('u1', null), isFalse);
      expect(e.isManagedBy(null, StaffRole.admin), isFalse);
      expect(e.isManagedBy('x', StaffRole.admin), isTrue);
    });

    test('a missing event, or a malformed id, is null', () async {
      expect(await repo.watchEvent('nope').first, isNull);
      expect(await repo.watchEvent('a/b').first, isNull);
    });
  });

  group('list', () {
    setUp(() async {
      await seed(
        'a',
        eventDoc(title: 'A', startAt: eventNow.add(const Duration(days: 1))),
      );
      await seed(
        'b',
        eventDoc(
          title: 'B',
          type: 'workshop',
          price: 0,
          status: 'full',
          startAt: eventNow.add(const Duration(days: 2)),
        ),
      );
      await seed(
        'c',
        eventDoc(
          title: 'C',
          type: 'workshop',
          startAt: eventNow.add(const Duration(days: 3)),
        ),
      );
      await seed(
        'old',
        eventDoc(
          title: 'Old',
          startAt: eventNow.subtract(const Duration(days: 1)),
        ),
      );
      await seed('draft', eventDoc(status: 'draft'));
      await seed('closed', eventDoc(status: 'closed'));
      await seed('cancelled', eventDoc(status: 'cancelled'));
    });

    test('list asks status in open/full ordered by startAt', () async {
      final page = await repo.list(from: eventNow);
      expect(page.events.map((e) => e.id), ['a', 'b', 'c']);
      expect(page.nextCursor, isNull);
    });

    test('list with a type and freeOnly adds both filters', () async {
      expect(
        (await repo.list(
          from: eventNow,
          type: EventType.workshop,
        )).events.map((e) => e.id),
        ['b', 'c'],
      );
      expect(
        (await repo.list(
          from: eventNow,
          freeOnly: true,
        )).events.map((e) => e.id),
        ['b'],
      );
      expect(
        (await repo.list(
          from: eventNow,
          type: EventType.workshop,
          freeOnly: true,
        )).events.map((e) => e.id),
        ['b'],
      );
      expect(
        (await repo.list(from: eventNow, type: EventType.cosplay)).events,
        isEmpty,
      );
    });

    test('list pages with a cursor', () async {
      final first = await repo.list(from: eventNow, limit: 2);
      expect(first.events.map((e) => e.id), ['a', 'b']);
      expect(first.nextCursor, isNotNull);
      final second = await repo.list(
        from: eventNow,
        limit: 2,
        cursor: first.nextCursor,
      );
      expect(second.events.map((e) => e.id), ['c']);
      expect(second.nextCursor, isNull);
    });
  });

  group('own data', () {
    test('watchMine asks createdBy == me or hostId == me, drafts first, latest first', () async {
      await seed(
        'x1',
        eventDoc(
          createdBy: 'u1',
          hostId: 'u1',
          startAt: eventNow.add(const Duration(days: 1)),
        ),
      );
      await seed(
        'x2',
        eventDoc(
          createdBy: 'u1',
          hostId: 'u1',
          startAt: eventNow.add(const Duration(days: 5)),
        ),
      );
      await seed(
        'dr',
        eventDoc(
          createdBy: 'u1',
          hostId: 'u1',
          status: 'draft',
          schedule: false,
        ),
      );
      await seed('other', eventDoc(createdBy: 'u2'));
      final mine = await repo.watchMine().first;
      expect(mine.map((e) => e.id), ['dr', 'x2', 'x1']);
      expect(mine.first.hasSchedule, isFalse);
      expect(mine.first.status, EventStatus.draft);
      expect(await repoFor(null).watchMine().first, isEmpty);
    });

    test(
      'watchMine also lists staff-made events I host, not invitations',
      () async {
        await seed(
          'hosted',
          eventDoc(createdBy: 'staff1', createdByRole: 'sales', hostId: 'u1'),
        );
        await seed(
          'accepted-draft',
          eventDoc(
            createdBy: 'staff1',
            createdByRole: 'sales',
            hostId: 'u1',
            status: 'draft',
            hostConsent: 'accepted',
          ),
        );
        await seed(
          'invite',
          eventDoc(
            createdBy: 'staff1',
            createdByRole: 'sales',
            hostId: 'u1',
            status: 'draft',
            hostConsent: 'pending',
          ),
        );
        await seed('theirs', eventDoc(createdBy: 'staff1', hostId: 'p9'));
        final ids = (await repo.watchMine().first).map((e) => e.id).toSet();
        expect(ids, {'hosted', 'accepted-draft'});
      },
    );

    test('host invitations are my pending staff drafts', () async {
      final soon = eventNow.add(const Duration(hours: 5));
      final later = eventNow.add(const Duration(hours: 20));
      await seed(
        'i2',
        eventDoc(
          status: 'draft',
          hostId: 'u1',
          createdBy: 's1',
          createdByRole: 'sales',
          hostConsent: 'pending',
          hostConsentExpiresAt: later,
        ),
      );
      await seed(
        'i1',
        eventDoc(
          status: 'draft',
          hostId: 'u1',
          createdBy: 's1',
          hostConsent: 'pending',
          hostConsentExpiresAt: soon,
        ),
      );
      await seed(
        'done',
        eventDoc(
          status: 'draft',
          hostId: 'u1',
          createdBy: 's1',
          hostConsent: 'accepted',
        ),
      );
      await seed(
        'pub',
        eventDoc(
          status: 'open',
          hostId: 'u1',
          createdBy: 's1',
          hostConsent: 'pending',
        ),
      );
      await seed(
        'else',
        eventDoc(status: 'draft', hostId: 'u9', hostConsent: 'pending'),
      );
      final list = await repo.watchHostInvitations().first;
      expect(list.map((e) => e.id), ['i1', 'i2']);
      expect(list.first.hostConsent, HostConsent.pending);
      expect(list.first.hostConsentExpiresAt, soon);
    });

    test(
      'my tickets come from the registrations collection group, newest first',
      () async {
        await seed('ev1', eventDoc());
        await seed('ev2', eventDoc());
        Future<void> reg(String ev, String id, String user, DateTime at) => db
            .collection('events')
            .doc(ev)
            .collection('registrations')
            .doc(id)
            .set(registrationDoc(eventId: ev, userId: user, createdAt: at));
        await reg(
          'ev1',
          'r1',
          'u1',
          eventNow.subtract(const Duration(days: 2)),
        );
        await reg('ev2', 'r2', 'u1', eventNow);
        await reg('ev2', 'r3', 'u2', eventNow);
        final tickets = await repo.watchMyTickets().first;
        expect(tickets.map((t) => t.id), ['r2', 'r1']);
        expect(tickets.every((t) => t.userId == 'u1'), isTrue);
      },
    );

    test('a registration parses its event snapshot', () async {
      await seed('ev1', eventDoc());
      await db
          .collection('events')
          .doc('ev1')
          .collection('registrations')
          .doc('r1')
          .set(
            registrationDoc(
              amount: 500000,
              quantity: 2,
              contactEligible: true,
              checkedInAt: eventNow,
            ),
          );
      final r = (await repo.watchMyRegistration('ev1').first)!;
      expect(r.id, 'r1');
      expect(
        (r.quantity, r.amount, r.status),
        (2, 500000, RegistrationStatus.paid),
      );
      expect(r.ticketCode, 'VE-AB2C-1013');
      expect(r.contactEligible, isTrue);
      expect(r.isCheckedIn, isTrue);
      expect(r.paymentId, 'pay1');
      expect(r.event.title, 'Photo walk phố cổ');
      expect(r.event.type, EventType.photoWalk);
      expect(r.event.startsAt, eventNow.add(const Duration(days: 3)));
      expect(r.event.endsAt, eventNow.add(const Duration(days: 3, hours: 2)));
      expect(r.event.locationName, 'Công viên Bạch Đằng');
      expect((r.event.lat, r.event.lng), (10.78, 106.70));
      expect(r.event.coverUrl, 'https://img.test/cover.jpg');
    });

    test('a free registration is never contact-eligible', () async {
      await seed('ev1', eventDoc(price: 0));
      await db
          .collection('events')
          .doc('ev1')
          .collection('registrations')
          .doc('r1')
          .set(registrationDoc());
      final r = (await repo.watchMyRegistration('ev1').first)!;
      expect(r.isFree, isTrue);
      expect(r.contactEligible, isFalse);
    });

    test(
      'my registration prefers the active one over a newer cancelled one',
      () async {
        await seed('ev1', eventDoc());
        final regs = db
            .collection('events')
            .doc('ev1')
            .collection('registrations');
        await regs
            .doc('old')
            .set(
              registrationDoc(
                createdAt: eventNow.subtract(const Duration(days: 1)),
              ),
            );
        await regs.doc('new').set(registrationDoc(status: 'cancelled'));
        await regs.doc('someone').set(registrationDoc(userId: 'u2'));
        expect((await repo.watchMyRegistration('ev1').first)!.id, 'old');
        await regs.doc('old').update({'status': 'cancelled'});
        expect((await repo.watchMyRegistration('ev1').first)!.id, 'new');
        expect(await repoFor('u3').watchMyRegistration('ev1').first, isNull);
      },
    );

    test('managers read every registration, newest first', () async {
      await seed('ev1', eventDoc());
      final regs = db
          .collection('events')
          .doc('ev1')
          .collection('registrations');
      await regs
          .doc('a')
          .set(
            registrationDoc(
              userId: 'u1',
              createdAt: eventNow.subtract(const Duration(hours: 1)),
            ),
          );
      await regs.doc('b').set(registrationDoc(userId: 'u2'));
      final all = await repo.watchRegistrations('ev1').first;
      expect(all.map((r) => r.id), ['b', 'a']);
    });
  });

  group('attendee contact', () {
    Future<void> seedReg({
      required bool eligible,
      String status = 'paid',
    }) async {
      await seed('ev1', eventDoc());
      final reg = db
          .collection('events')
          .doc('ev1')
          .collection('registrations')
          .doc('r1');
      await reg.set(
        registrationDoc(
          amount: eligible ? 250000 : 0,
          contactEligible: eligible,
          status: status,
        ),
      );
      await reg.collection('private').doc('contact').set({
        'name': 'Lan',
        'phone': '0901234567',
        'allowZalo': true,
        'allowWhatsApp': false,
      });
    }

    test('a paid, eligible ticket exposes the phone to a manager', () async {
      await seedReg(eligible: true);
      final c = await repo.watchRegistrationContact('ev1', 'r1').first;
      expect(c?.phone, '0901234567');
      expect(c?.allowZalo, isTrue);
    });

    test(
      'a free ticket never exposes a phone, even if a snapshot exists',
      () async {
        await seedReg(eligible: false);
        expect(await repo.watchRegistrationContact('ev1', 'r1').first, isNull);
      },
    );

    test('a ticket that is no longer paid exposes nothing', () async {
      await seedReg(eligible: true, status: 'cancelled');
      expect(await repo.watchRegistrationContact('ev1', 'r1').first, isNull);
    });

    test('no contact document is null', () async {
      await seed('ev1', eventDoc());
      expect(await repo.watchRegistrationContact('ev1', 'r9').first, isNull);
    });
  });

  group('callables', () {
    void failWith(String code) => when(() => callable.call<Object?>(any()))
        .thenThrow(
          FirebaseFunctionsException(
            message: 'x',
            code: 'failed-precondition',
            details: {'code': code},
          ),
        );

    test('callable errors become EventError codes', () async {
      for (final code in ['sold_out', 'phone_required', 'day_taken']) {
        failWith(code);
        await expectLater(
          repo.register('ev1', quantity: 1, name: 'Lan'),
          throwsA(isA<EventError>().having((e) => e.code, 'code', code)),
        );
      }
      failWith('day_taken');
      await expectLater(
        repo.publish('ev1'),
        throwsA(isA<EventError>().having((e) => e.code, 'code', 'day_taken')),
      );
    });

    test(
      'an offline call is a network error, anything else keeps its code',
      () async {
        when(() => callable.call<Object?>(any())).thenThrow(
          FirebaseFunctionsException(message: 'm', code: 'unavailable'),
        );
        await expectLater(
          repo.cancelEvent('ev1'),
          throwsA(isA<EventError>().having((e) => e.code, 'code', 'network')),
        );
        expect(eventErrorCodeOf(const EventError('conflict')), 'conflict');
        expect(eventErrorCodeOf(StateError('x')), 'unknown');
      },
    );

    test(
      'saveDraft sends only filled fields and returns the hashtag',
      () async {
        answer({'eventId': 'e' * 24, 'hashtag': 'PhotoWalk1013'});
        final out = await repo.saveDraft(
          EventDraft(
            eventId: 'e' * 24,
            title: 'Photo walk',
            type: EventType.photoWalk,
            startsAt: eventNow.add(const Duration(days: 3)),
            priceVnd: 0,
            place: const EventPlace(name: 'Bạch Đằng', lat: 10.78, lng: 106.7),
          ),
        );
        expect(out.eventId, 'e' * 24);
        expect(out.hashtag, 'PhotoWalk1013');
        verify(
          () => callable.call<Object?>({
            'eventId': 'e' * 24,
            'title': 'Photo walk',
            'type': 'photo_walk',
            'startAt': '2026-10-13T03:00:00.000Z',
            'location': {'name': 'Bạch Đằng', 'lat': 10.78, 'lng': 106.7},
            'price': 0,
          }),
        ).called(1);
        verify(
          () => functions.httpsCallable(
            'saveEventDraft',
            options: any(named: 'options'),
          ),
        ).called(1);
      },
    );

    test('an empty draft sends an empty payload', () async {
      answer({'eventId': 'e' * 24, 'hashtag': 'X'});
      await repo.saveDraft(const EventDraft());
      verify(() => callable.call<Object?>(<String, Object?>{})).called(1);
    });

    test(
      'registerEvent sends quantity, name and provider and parses the outcome',
      () async {
        answer({
          'registrationId': 'r1',
          'status': 'held',
          'paymentId': 'pay1',
          'payUrl': 'https://pay.test/1',
          'holdExpiresAt': '2026-10-10T03:10:00.000Z',
        });
        final out = await repo.register(
          'ev1',
          quantity: 2,
          name: 'Lan',
          provider: PaymentProviderCode.momo,
        );
        expect(out.registrationId, 'r1');
        expect(out.status, RegistrationStatus.held);
        expect(out.paymentId, 'pay1');
        expect(out.payUrl, 'https://pay.test/1');
        expect(out.holdExpiresAt, DateTime.utc(2026, 10, 10, 3, 10));
        verify(
          () => callable.call<Object?>({
            'eventId': 'ev1',
            'quantity': 2,
            'name': 'Lan',
            'provider': 'momo',
          }),
        ).called(1);
      },
    );

    test('a free registration has no payment or hold', () async {
      answer({
        'registrationId': 'r1',
        'status': 'paid',
        'paymentId': null,
        'payUrl': null,
        'holdExpiresAt': null,
      });
      final out = await repo.register('ev1', quantity: 1, name: 'Lan');
      expect(out.status, RegistrationStatus.paid);
      expect(
        (out.paymentId, out.payUrl, out.holdExpiresAt),
        (null, null, null),
      );
      verify(
        () => callable.call<Object?>({
          'eventId': 'ev1',
          'quantity': 1,
          'name': 'Lan',
        }),
      ).called(1);
    });

    test(
      'cancelRegistration, checkIn and the consent answer use their callables',
      () async {
        answer({'status': 'refunded', 'refundPercent': 100});
        final c = await repo.cancelRegistration('ev1', 'r1');
        expect((c.status, c.refundPercent), (RegistrationStatus.refunded, 100));
        verify(
          () => callable.call<Object?>({
            'eventId': 'ev1',
            'registrationId': 'r1',
          }),
        ).called(1);

        answer({'name': 'Lan', 'quantity': 2});
        final ci = await repo.checkIn('ev1', 'VE-AB2C-1013');
        expect((ci.name, ci.quantity), ('Lan', 2));
        verify(
          () => callable.call<Object?>({
            'eventId': 'ev1',
            'ticketCode': 'VE-AB2C-1013',
          }),
        ).called(1);

        answer(<String, Object?>{});
        await repo.respondToHostConsent('ev1', accept: true);
        verify(() => callable.call<Object?>({'eventId': 'ev1', 'accept': true}))
            .called(1);
        verify(
          () => functions.httpsCallable(
            'respondToHostConsent',
            options: any(named: 'options'),
          ),
        ).called(1);
      },
    );
  });

  group('ticket payments', () {
    test(
      'confirmFakeTicketPayment sends the payment id and parses the status',
      () async {
        answer({'status': 'paid'});
        expect(
          await repo.confirmFakeTicketPayment('pay1'),
          RegistrationStatus.paid,
        );
        verify(() => callable.call<Object?>({'paymentId': 'pay1'})).called(1);
        verify(
          () => functions.httpsCallable(
            'confirmFakeTicketPayment',
            options: any(named: 'options'),
          ),
        ).called(1);
      },
    );

    test('checkTicketPayment sends event and registration', () async {
      answer({'paid': false, 'status': 'held'});
      final r = await repo.checkTicketPayment('ev1', 'r1');
      expect((r.paid, r.status), (false, RegistrationStatus.held));
      verify(
        () =>
            callable.call<Object?>({'eventId': 'ev1', 'registrationId': 'r1'}),
      ).called(1);
    });

    test('fake payments refused by the server surface their code', () async {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(
          message: 'fake_payments_disabled',
          code: 'failed-precondition',
          details: {'code': 'fake_payments_disabled'},
        ),
      );
      await expectLater(
        repo.confirmFakeTicketPayment('pay1'),
        throwsA(
          isA<EventError>().having(
            (e) => e.code,
            'code',
            'fake_payments_disabled',
          ),
        ),
      );
    });

    test(
      'registerEvent and the payment callables wait longer than 30 s',
      () async {
        answer({'registrationId': 'r1', 'status': 'paid'});
        await repo.register('ev1', quantity: 1, name: 'Lan');
        final options =
            verify(
                  () => functions.httpsCallable(
                    'registerEvent',
                    options: captureAny(named: 'options'),
                  ),
                ).captured.single
                as HttpsCallableOptions;
        expect(options.timeout, greaterThan(const Duration(seconds: 30)));
      },
    );

    test('a refund-due ticket parses refundDue', () async {
      final doc = registrationDoc(amount: 250000)..['refundDue'] = true;
      await db.doc('events/ev1/registrations/r-u1').set(doc);
      final mine = await repo.watchMyTickets().first;
      expect(mine.single.refundDue, isTrue);
    });
  });

  group('cover upload', () {
    test('the upload path is eventCovers/uid/eventId', () async {
      final eventId = 'e' * 24;
      final url = await repo.uploadCover(
        eventId,
        const PickedImage(path: '/tmp/a.jpg', name: 'a.jpg'),
      );
      expect(
        uploader.uploaded.single,
        matches(RegExp('^eventCovers/u1/$eventId/[0-9A-Z]{26}\\.jpg\$')),
      );
      expect(url, 'https://storage.test/${uploader.uploaded.single}');
    });

    test(
      'saveDraft sends the remembered coverPath for an uploaded cover',
      () async {
        final eventId = 'e' * 24;
        final url = await repo.uploadCover(
          eventId,
          const PickedImage(path: '/tmp/a.jpg', name: 'a.jpg'),
        );
        answer({'eventId': eventId, 'hashtag': 'X'});
        await repo.saveDraft(EventDraft(eventId: eventId, coverUrl: url));
        verify(
          () => callable.call<Object?>({
            'eventId': eventId,
            'coverUrl': url,
            'coverPath': uploader.uploaded.single,
          }),
        ).called(1);
      },
    );

    test('a failed upload is an error and signed out cannot upload', () async {
      uploader.failNames.add('bad.jpg');
      await expectLater(
        repo.uploadCover(
          'e' * 24,
          const PickedImage(path: '/x', name: 'bad.jpg'),
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repoFor(
          null,
        ).uploadCover('e' * 24, const PickedImage(path: '/x', name: 'a.jpg')),
        throwsA(isA<EventError>()),
      );
    });
  });

  test('EventDraft survives a round trip through JSON', () {
    final d = EventDraft(
      eventId: 'e' * 24,
      title: 'Photo walk',
      type: EventType.workshop,
      description: 'Mô tả',
      coverUrl: 'https://img.test/c.jpg',
      coverPath: 'eventCovers/u1/x/c.jpg',
      startsAt: eventNow,
      endsAt: eventNow.add(const Duration(hours: 2)),
      place: const EventPlace(
        name: 'Bạch Đằng',
        lat: 10.78,
        lng: 106.7,
        meetingPoint: 'Cổng',
        areaId: 'hcm-q1',
      ),
      capacity: 12,
      priceVnd: 200000,
      registrationDeadline: eventNow,
      hashtag: 'PhotoWalk',
      faq: const [EventFaq(question: 'Q', answer: 'A')],
      hostPhotographerId: 'p1',
    );
    expect(EventDraft.fromJson(d.toJson()), d);
    expect(EventDraft.fromJson(d.toJson()).hashCode, d.hashCode);
    expect(
      EventDraft.fromJson(const {'startsAt': 'nope', 'capacity': 'x'}),
      const EventDraft(),
    );
  });

  group('refused reads', () {
    test(
      'a permission-denied event stream is null, other errors pass',
      () async {
        final denied = _deniedDb('events');
        final r = FirestoreEventRepository(
          uid: 'u1',
          uploader: uploader,
          db: denied,
          functions: functions,
        );
        expect(await r.watchEvent('ev1').first, isNull);
        expect(await r.watchRegistrations('ev1').first, isEmpty);
        final other = FirestoreEventRepository(
          uid: 'u1',
          uploader: uploader,
          db: _deniedDb('events', code: 'unavailable'),
          functions: functions,
        );
        await expectLater(
          other.watchEvent('ev1'),
          emitsError(isA<FirebaseException>()),
        );
      },
    );

    test('a denied contact stream is null', () async {
      final r = FirestoreEventRepository(
        uid: 'u1',
        uploader: uploader,
        db: _deniedDb('events'),
        functions: functions,
      );
      expect(await r.watchRegistrationContact('ev1', 'r1').first, isNull);
    });
  });

  test('a cleared field is sent as an explicit null', () {
    const base = EventDraft(
      eventId: 'e',
      coverUrl: 'u',
      coverPath: 'p',
      place: EventPlace(name: 'n', lat: 1, lng: 2),
    );
    final cleared = base.copyWith(
      clearCover: true,
      clearPlace: true,
      clearDeadline: true,
    );
    expect(cleared.toCallable(), {
      'eventId': 'e',
      'coverUrl': null,
      'coverPath': null,
      'location': null,
      'registrationDeadline': null,
    });
    expect(
      EventDraft.fromJson(cleared.toJson()).toCallable(),
      cleared.toCallable(),
    );
    // A new value drops the clear.
    expect(
      cleared.copyWith(coverUrl: 'v', coverPath: 'q').toCallable()['coverUrl'],
      'v',
    );
    expect(base.toCallable().containsKey('location'), isTrue);
    expect(const EventDraft(eventId: 'e').toCallable(), {'eventId': 'e'});
  });
}

class _MockDb extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class _MockCol extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

/// A database where every event, registration and contact stream fails with
/// [code], like a rules refusal.
FirebaseFirestore _deniedDb(String _, {String code = 'permission-denied'}) {
  Stream<T> fail<T>() =>
      Stream<T>.error(FirebaseException(plugin: 'cloud_firestore', code: code));
  final db = _MockDb();
  final events = _MockCol();
  final eventDoc = _MockDoc();
  final regs = _MockCol();
  final regDoc = _MockDoc();
  final priv = _MockCol();
  final contactDoc = _MockDoc();
  when(() => db.collection('events')).thenReturn(events);
  when(() => events.doc(any())).thenReturn(eventDoc);
  when(() => eventDoc.snapshots()).thenAnswer((_) => fail());
  when(() => eventDoc.collection('registrations')).thenReturn(regs);
  when(() => regs.snapshots()).thenAnswer((_) => fail());
  when(() => regs.doc(any())).thenReturn(regDoc);
  when(() => regDoc.collection('private')).thenReturn(priv);
  when(() => priv.doc('contact')).thenReturn(contactDoc);
  when(() => contactDoc.snapshots()).thenAnswer((_) => fail());
  return db;
}
