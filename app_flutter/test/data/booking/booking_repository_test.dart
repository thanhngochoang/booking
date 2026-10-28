import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/booking/firestore_booking_repository.dart';

import '../../support/booking_fixtures.dart';
import '../../support/fake_booking_repository.dart';

void main() {
  test('bookingErrorOf maps not_accepting_orders to notAcceptingOrders', () {
    expect(
      bookingErrorOf(const BookingException('not_accepting_orders')),
      BookingErrorCode.notAcceptingOrders,
    );
  });

  test('bookingErrorOf maps blocked to blocked', () {
    expect(
      bookingErrorOf(const BookingException('blocked')),
      BookingErrorCode.blocked,
    );
  });

  test('bookingErrorOf maps outside_schedule, slot_taken, spot_archived', () {
    expect(
      bookingErrorOf(const BookingException('outside_schedule')),
      BookingErrorCode.outsideSchedule,
    );
    expect(
      bookingErrorOf(const BookingException('slot_taken')),
      BookingErrorCode.slotTaken,
    );
    expect(
      bookingErrorOf(const BookingException('spot_archived')),
      BookingErrorCode.spotArchived,
    );
  });

  group('FakeBookingRepository', () {
    late FakeBookingRepository repo;

    setUp(() {
      repo = FakeBookingRepository(customerId: 'c1');
    });

    test('createBooking creates draft booking and emits on watch', () async {
      final b = await repo.createBooking(
        photographerId: 'p1',
        serviceId: 's1',
        day: '2026-10-20',
        start: '09:00',
        place: const BookingPlace(name: 'Hà Nội'),
      );

      expect(b.status, BookingStatus.draft);
      expect(b.customerId, 'c1');
      expect(b.photographerId, 'p1');

      final loaded = await repo.getBooking(b.id);
      expect(loaded, isNotNull);
      expect(loaded?.id, b.id);
    });

    test('createBooking sends spotScheduleId and slotOfferId only when given', () async {
      await repo.createBooking(
        photographerId: 'p1',
        serviceId: 's1',
        day: '2026-10-20',
        start: '09:00',
        place: const BookingPlace(name: 'Hồ Tây'),
        spotScheduleId: 'sch_1',
        slotOfferId: 'off_1',
      );
      expect(repo.createCalls.last.spotScheduleId, 'sch_1');
      expect(repo.createCalls.last.slotOfferId, 'off_1');

      await repo.createBooking(
        photographerId: 'p1',
        serviceId: 's1',
        day: '2026-10-20',
        start: '09:00',
        place: const BookingPlace(name: 'Hà Nội'),
      );
      expect(repo.createCalls.last.spotScheduleId, isNull);
      expect(repo.createCalls.last.slotOfferId, isNull);
    });

    test('deposit payment flow moves draft to requested', () async {
      final draft = await repo.createBooking(
        photographerId: 'p1',
        serviceId: 's1',
        day: '2026-10-20',
        start: '09:00',
        place: const BookingPlace(name: 'Hà Nội'),
      );

      final checkout = await repo.createPayment(
        bookingId: draft.id,
        method: PayMethod.bankQr,
      );
      expect(checkout.paymentId, 'pay_${draft.id}');
      expect((await repo.getBooking(draft.id))?.checkout?.paymentId,
          checkout.paymentId);

      final outcome = await repo.confirmFakePayment(
        paymentId: checkout.paymentId,
      );
      expect(outcome, 'paid');
      final paid = await repo.getBooking(draft.id);
      expect(paid?.status, BookingStatus.requested);
      expect(paid?.escrowStatus, EscrowStatus.held);

      final check = await repo.checkPayment(bookingId: draft.id);
      expect(check.paid, true);
    });

    test('lifecycle transitions update status', () async {
      final b = makeTestBooking(id: 'b1', status: BookingStatus.requested);
      repo.seedBooking(b);

      final accepted = await repo.transitionBooking(
        bookingId: 'b1',
        action: 'accept',
      );
      expect(accepted.status, BookingStatus.accepted);

      final completed = await repo.transitionBooking(
        bookingId: 'b1',
        action: 'complete',
      );
      expect(completed.status, BookingStatus.completed);
      expect(completed.completedAt, isNotNull);
    });

    test('watchCustomerBookings filters out drafts', () async {
      final b1 = makeTestBooking(id: 'b1', status: BookingStatus.requested);
      final b2 = makeTestBooking(id: 'b2', status: BookingStatus.draft);
      repo.seedBooking(b1);
      repo.seedBooking(b2);

      final list = await repo.watchCustomerBookings('c1').first;
      expect(list.length, 1);
      expect(list.first.id, 'b1');
    });
  });

  group('watchAssignedBookings', () {
    Map<String, dynamic> doc(
      String status, {
      String? assigneeId,
      String? assignStatus = 'assigned',
      Map<String, dynamic> extra = const {},
    }) => {
      'customerId': 'c1',
      'photographerId': 'studio1',
      'serviceId': 's1',
      'serviceSnapshot': {'name': 'G', 'price': 1000000, 'durationMinutes': 60},
      'day': '2026-10-20',
      'start': '09:00',
      'end': '10:00',
      'place': {'name': 'Hà Nội'},
      'status': status,
      'deposit': 1000000,
      'remaining': 0,
      'assigneeId': ?assigneeId,
      'assignStatus': ?assignStatus,
      ...extra,
    };

    test(
      'reads bookings where assigneeId is the uid, drafts dropped',
      () async {
        final db = FakeFirebaseFirestore();
        final repo = FirestoreBookingRepository(firestore: db);
        final col = db.collection('bookings');
        await col.doc('a1').set(doc('accepted', assigneeId: 'p1'));
        await col.doc('a2').set(doc('draft', assigneeId: 'p1'));
        await col.doc('a3').set(doc('accepted', assigneeId: 'p2'));
        await col.doc('a4').set(doc('accepted'));
        final list = await repo.watchAssignedBookings('p1').first;
        expect([for (final b in list) b.id], ['a1']);
      },
    );

    test('a pending collaborator offer is not an assigned job (S27)', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreBookingRepository(firestore: db);
      final col = db.collection('bookings');
      const collab = {'assigneeKind': 'collaborator'};
      await col
          .doc('pending')
          .set(
            doc(
              'accepted',
              assigneeId: 'p1',
              assignStatus: 'unassigned',
              extra: {...collab, 'assigneeAccepted': false},
            ),
          );
      await col
          .doc('accepted')
          .set(
            doc(
              'upcoming',
              assigneeId: 'p1',
              extra: {...collab, 'assigneeAccepted': true},
            ),
          );
      await col.doc('member').set(doc('accepted', assigneeId: 'p1'));
      final list = await repo.watchAssignedBookings('p1').first;
      expect([for (final b in list) b.id]..sort(), ['accepted', 'member']);
    });

    test('the fake emits assigned lists and errors', () async {
      final repo = FakeBookingRepository();
      final seen = <Object>[];
      final sub = repo
          .watchAssignedBookings('p1')
          .listen(
            (l) => seen.add([for (final b in l) b.id]),
            onError: (Object e) => seen.add('error'),
          );
      await Future<void>.delayed(Duration.zero);
      repo.emitAssigned([makeTestBooking(id: 'x1', photographerId: 'studio1')]);
      await Future<void>.delayed(Duration.zero);
      repo.failAssigned(StateError('permission-denied'));
      await Future<void>.delayed(Duration.zero);
      expect(seen, [
        <String>[],
        ['x1'],
        'error',
      ]);
      await sub.cancel();
    });
  });

  group('bookingFromFirestore mapper', () {
    test('maps valid Firestore document correctly', () {
      final docData = <String, dynamic>{
        'customerId': 'c1',
        'photographerId': 'p1',
        'serviceId': 's1',
        'serviceSnapshot': {
          'name': 'Gói chụp chân dung',
          'price': 1500000,
          'durationMinutes': 120,
        },
        'day': '2026-10-20',
        'start': '08:00',
        'end': '10:00',
        'place': {
          'name': 'Hồ Gươm',
          'point': const GeoPoint(21.0285, 105.8542),
        },
        'note': 'Chụp sáng sớm',
        'status': 'accepted',
        'deposit': 450000,
        'remaining': 1050000,
        'escrowStatus': 'held',
        'depositProvider': 'fake',
        'depositPaidAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1, 8, 0)),
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1, 7, 0)),
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1, 8, 0)),
      };

      final b = bookingFromFirestore('b_fs_1', docData);
      expect(b, isNotNull);
      expect(b?.id, 'b_fs_1');
      expect(b?.customerId, 'c1');
      expect(b?.status, BookingStatus.accepted);
      expect(b?.deposit, 450000);
      expect(b?.remaining, 1050000);
      expect(b?.place.lat, 21.0285);
      expect(b?.place.lng, 105.8542);
      expect(b?.escrowStatus, EscrowStatus.held);
    });

    test('Booking maps disputeId', () {
      final docData = <String, dynamic>{
        'customerId': 'c1',
        'photographerId': 'p1',
        'serviceId': 's1',
        'serviceSnapshot': {'name': 'G', 'price': 1000000, 'durationMinutes': 60},
        'status': 'completed',
        'deposit': 1000000,
        'remaining': 0,
        'escrowStatus': 'disputed',
      };
      expect(bookingFromFirestore('b', docData)?.disputeId, isNull);
      final b = bookingFromFirestore('b', {...docData, 'disputeId': 'd1'});
      expect(b?.disputeId, 'd1');
      expect(b?.escrowStatus, EscrowStatus.disputed);
    });

    test('Booking parses refundAccountNeeded (missing → false)', () {
      final docData = <String, dynamic>{
        'customerId': 'c1',
        'photographerId': 'p1',
        'serviceId': 's1',
        'serviceSnapshot': {'name': 'G', 'price': 1000000, 'durationMinutes': 60},
        'status': 'cancelled',
        'deposit': 1000000,
        'remaining': 0,
      };
      expect(bookingFromFirestore('b', docData)?.refundAccountNeeded, isFalse);
      expect(
        bookingFromFirestore('b', {...docData, 'refundAccountNeeded': true})
            ?.refundAccountNeeded,
        isTrue,
      );
      expect(
        bookingFromFirestore('b', {...docData, 'refundAccountNeeded': 'yes'})
            ?.refundAccountNeeded,
        isFalse,
      );
    });

    test('bookingFromFirestore reads spotId, spotScheduleId, slotOfferId, source', () {
      final docData = <String, dynamic>{
        'customerId': 'c1',
        'photographerId': 'p1',
        'serviceId': 's1',
        'serviceSnapshot': {'name': 'G', 'price': 1000000, 'durationMinutes': 60},
        'day': '2026-10-20',
        'start': '08:00',
        'end': '08:30',
        'place': {'name': 'Hồ Tây'},
        'status': 'draft',
        'deposit': 490000,
        'remaining': 0,
        'spotId': 'seed-spot-ho-tay',
        'spotScheduleId': 'seed-schedule-an',
        'slotOfferId': 'seed-offer-binh-minh',
        'source': 'spot_slot',
      };
      final b = bookingFromFirestore('b_spot', docData);
      expect(b, isNotNull);
      expect(b?.spotId, 'seed-spot-ho-tay');
      expect(b?.spotScheduleId, 'seed-schedule-an');
      expect(b?.slotOfferId, 'seed-offer-binh-minh');
      expect(b?.source, 'spot_slot');
    });

    test('maps the checkout mirror, or null when absent or malformed', () {
      final base = <String, dynamic>{
        'customerId': 'c1',
        'photographerId': 'p1',
        'serviceId': 's1',
        'serviceSnapshot': {'name': 'G', 'price': 1000000, 'durationMinutes': 60},
        'status': 'draft',
        'deposit': 1000000,
        'remaining': 0,
      };
      expect(bookingFromFirestore('b', base)?.checkout, isNull);

      final withCheckout = bookingFromFirestore('b', {
        ...base,
        'checkout': {
          'paymentId': 'pay_1',
          'method': 'bank_qr',
          'amount': 1000000,
          'expiresAt': Timestamp.fromDate(DateTime.utc(2026, 10, 7, 3, 15)),
          'transferCode': 'PB 7F3K2Q',
          'attempt': 1,
        },
      });
      expect(withCheckout?.checkout?.paymentId, 'pay_1');
      expect(withCheckout?.checkout?.expiresAt, DateTime.utc(2026, 10, 7, 3, 15));

      // A broken mirror never breaks the booking itself.
      final broken = bookingFromFirestore('b', {...base, 'checkout': {'x': 1}});
      expect(broken, isNotNull);
      expect(broken?.checkout, isNull);
    });

    test('returns null for missing required fields', () {
      expect(bookingFromFirestore('b_bad', {}), isNull);
      expect(bookingFromFirestore('b_bad', {'customerId': 'c1'}), isNull);
    });
  });
}
