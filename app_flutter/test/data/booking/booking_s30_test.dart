import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/booking/contact_access.dart';
import 'package:photobooking/data/booking/firestore_booking_repository.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

Map<String, dynamic> _wire(
  String status, [
  Map<String, dynamic> extra = const {},
]) => {
  'id': 'b1',
  'customerId': 'c1',
  'photographerId': 'p1',
  'serviceId': 's1',
  'serviceSnapshot': {'name': 'Gói', 'price': 1000000, 'durationMinutes': 120},
  'day': '2026-11-21',
  'start': '09:00',
  'end': '11:00',
  'place': {'name': 'Bãi đá'},
  'status': status,
  'deposit': 1000000,
  'remaining': 0,
  'createdAt': '2026-10-07T03:00:00.000Z',
  'updatedAt': '2026-10-07T03:00:00.000Z',
  ...extra,
};

void main() {
  test(
    'BookingStatus.shooting parses and unknown statuses still map safely',
    () {
      expect(bookingStatusFromCode('shooting'), BookingStatus.shooting);
      expect(
        bookingFromFirestore('b1', _wire('shooting'))!.status,
        BookingStatus.shooting,
      );
      expect(
        bookingFromFirestore('b1', _wire('from_the_future'))!.status,
        BookingStatus.draft,
      );
      // `shooting` sits right after `upcoming`, as in BOOKING_STATUSES.
      expect(
        BookingStatus.values.indexOf(BookingStatus.shooting),
        BookingStatus.values.indexOf(BookingStatus.upcoming) + 1,
      );
    },
  );

  test('Booking.entry/groupId/passCode4/shootQuestionUntil map', () {
    final b = bookingFromFirestore(
      'b1',
      _wire('upcoming', {
        'entry': {
          'eventId': 'e1',
          'visitDay': '2026-11-21',
          'items': [
            {
              'ticketTypeId': 't1',
              'name': 'Người lớn',
              'price': 70000,
              'qty': 1,
            },
          ],
          'providerTicket': false,
          'waived': {'provider': true, 'guests': false},
          'waivedGuests': 0,
          'amount': 70000,
          'registrationId': 'r1',
        },
        'groupId': 'g1',
        'passCode4': '2QAB',
        'checkedInAt': '2026-11-21T02:00:00.000Z',
        'shootQuestionAt': '2026-11-22T04:00:00.000Z',
        'shootQuestionUntil': '2026-11-24T04:00:00.000Z',
        'shootDeniedAt': null,
      }),
    )!;
    expect(b.entry!.eventId, 'e1');
    expect(b.entry!.registrationId, 'r1');
    expect(b.entry!.items.single.qty, 1);
    expect(b.entry!.waivedProvider, isTrue);
    expect(b.entry!.waivedGuests, isFalse);
    expect(b.entry!.providerTicket, isFalse);
    expect(b.entry!.amount, 70000);
    expect(b.groupId, 'g1');
    expect(b.passCode4, '2QAB');
    expect(b.hasPass, isTrue);
    expect(b.checkedInAt, DateTime.parse('2026-11-21T02:00:00Z'));
    expect(b.shootQuestionAt, DateTime.parse('2026-11-22T04:00:00Z'));
    expect(b.shootQuestionUntil, DateTime.parse('2026-11-24T04:00:00Z'));
    expect(b.shootDeniedAt, isNull);
    expect(b.payTotalVnd, 1070000);

    final old = bookingFromFirestore('b1', _wire('upcoming'))!;
    expect(old.entry, isNull);
    expect(old.hasPass, isFalse);
    expect(old.payTotalVnd, 1000000);
  });

  group('the app `upcoming` sites (Task 4 list)', () {
    final l = AppLocalizationsVi();

    test('color, text color and label', () {
      expect(BookingStatus.shooting.color, AppColors.bookingOpened);
      expect(BookingStatus.shooting.onColor, AppColors.foreground);
      expect(BookingStatus.shooting.label(l), 'Đang chụp');
    });

    test('contact stays unlocked while shooting', () {
      expect(
        contactAccessForBooking(BookingStatus.shooting, now: DateTime.now()),
        ContactAccess.unlocked,
      );
    });

    Booking at(String status, {String? passCode4}) =>
        bookingFromFirestore('b1', _wire(status, {'passCode4': ?passCode4}))!;

    test('S05.01 bucket upcoming; no customer cancel', () {
      expect(BookingRules.tabForBooking(at('shooting')), BookingTab.upcoming);
      expect(BookingRules.canCustomerCancel(at('shooting')), isFalse);
    });

    test(
      'Đã chụp xong: any time while shooting; after the scan with a pass',
      () {
        final before = DateTime.parse('2026-11-21T01:00:00Z'); // 08:00 VN
        final after = DateTime.parse('2026-11-21T05:00:00Z'); // 12:00 VN
        expect(
          BookingRules.canPhotographerComplete(at('shooting'), before),
          isTrue,
        );
        expect(
          BookingRules.canPhotographerComplete(
            at('upcoming', passCode4: '2QAB'),
            after,
          ),
          isFalse,
        );
        expect(
          BookingRules.canPhotographerComplete(at('upcoming'), after),
          isTrue,
        );
        expect(
          BookingRules.canPhotographerComplete(at('upcoming'), before),
          isFalse,
        );
      },
    );
  });

  group('FirestoreBookingRepository S30 calls', () {
    late _MockFunctions functions;
    late _MockCallable callable;
    late FirestoreBookingRepository repo;

    setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

    setUp(() {
      functions = _MockFunctions();
      callable = _MockCallable();
      when(() => functions.httpsCallable(any(), options: any(named: 'options')))
          .thenReturn(callable);
      repo = FirestoreBookingRepository(
        firestore: FakeFirebaseFirestore(),
        functions: functions,
      );
    });

    void answer(Object? data) {
      final r = _MockResult();
      when(() => r.data).thenReturn(data);
      when(() => callable.call<Object?>(any())).thenAnswer((_) async => r);
    }

    test('createBooking sends entry {eventId, visitDay, items}', () async {
      answer(_wire('draft'));
      await repo.createBooking(
        photographerId: 'p1',
        serviceId: 's1',
        day: '2026-11-21',
        start: '09:00',
        place: const BookingPlace(name: 'Bãi đá'),
        entry: const BookingEntryRequest(
          eventId: 'e1',
          visitDay: '2026-11-21',
          items: [EntryItem(ticketTypeId: 't1', qty: 2)],
        ),
      );
      final payload =
          verify(() => callable.call<Object?>(captureAny())).captured.single
              as Map;
      expect(payload['entry'], {
        'eventId': 'e1',
        'visitDay': '2026-11-21',
        'items': [
          {'ticketTypeId': 't1', 'qty': 2},
        ],
      });
    });

    test('a booking without tickets sends no entry key', () async {
      answer(_wire('draft'));
      await repo.createBooking(
        photographerId: 'p1',
        serviceId: 's1',
        day: '2026-11-21',
        start: '09:00',
        place: const BookingPlace(name: 'Bãi đá'),
      );
      final payload =
          verify(() => callable.call<Object?>(captureAny())).captured.single
              as Map;
      expect(payload.containsKey('entry'), isFalse);
    });

    test('a customer cancel may keep the tickets', () async {
      answer(_wire('cancelled'));
      await repo.transitionBooking(
        bookingId: 'b1',
        action: 'cancel',
        keepTickets: true,
      );
      final payload =
          verify(() => callable.call<Object?>(captureAny())).captured.single
              as Map;
      expect(payload, {
        'bookingId': 'b1',
        'action': 'cancel',
        'keepTickets': true,
      });
    });

    test(
      'answerShootHappened sends {bookingId, happened} and reads status',
      () async {
        answer({'status': 'shot'});
        final s = await repo.answerShootHappened('b1', happened: true);
        expect(s, BookingStatus.shot);
        verify(
          () => functions.httpsCallable(
            'answerShootHappened',
            options: any(named: 'options'),
          ),
        );
        verify(
          () => callable.call<Object?>({'bookingId': 'b1', 'happened': true}),
        );
      },
    );

    test('S30 refusal codes map to booking errors', () {
      expect(
        bookingErrorOf(const BookingException('day_closed')),
        BookingErrorCode.dayClosed,
      );
      expect(
        bookingErrorOf(const BookingException('sold_out_day')),
        BookingErrorCode.soldOutDay,
      );
    });
  });
}
