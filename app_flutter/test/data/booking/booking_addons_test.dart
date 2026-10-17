import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/firestore_booking_repository.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

Map<String, dynamic> _doc({
  Object? addons,
  Object? pickup,
  Object? remaining,
  int deposit = 1000000,
}) => {
  'customerId': 'c1',
  'photographerId': 'p1',
  'serviceId': 's1',
  'serviceSnapshot': {'name': 'Gói', 'price': 1500000, 'durationMinutes': 120},
  'day': '2026-10-20',
  'start': '09:00',
  'end': '11:00',
  'place': {'name': 'Hà Nội'},
  'status': 'requested',
  'deposit': deposit,
  'remaining': ?remaining,
  'addons': ?addons,
  'pickup': ?pickup,
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
  'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
};

Map<String, dynamic> _line(
  String id,
  int amount, {
  String unit = 'per_person',
}) => {
  'addonId': id,
  'kind': 'makeup',
  'name': 'Trang điểm',
  'unit': unit,
  'unitPrice': amount ~/ 2,
  'qty': 2,
  'amount': amount,
};

void main() {
  group('Booking add-on fields', () {
    test('bookingFromFirestore reads addons and pickup', () {
      final b = bookingFromFirestore(
        'b1',
        _doc(
          addons: [_line('a1', 1600000)],
          pickup: {
            'name': 'Sân bay Nội Bài',
            'point': const GeoPoint(21.2, 105.8),
          },
        ),
      )!;
      expect(b.addons, hasLength(1));
      expect(b.addons.single.addonId, 'a1');
      expect(b.addons.single.kind, AddonKind.makeup);
      expect(b.addons.single.unit, AddonUnit.perPerson);
      expect(b.addons.single.unitPrice, 800000);
      expect(b.addons.single.qty, 2);
      expect(b.addons.single.amount, 1600000);
      expect(b.pickup?.name, 'Sân bay Nội Bài');
      expect(b.pickup?.lat, 21.2);
      expect(b.pickup?.lng, 105.8);
    });

    test('missing addons → [] and no pickup', () {
      final b = bookingFromFirestore('b1', _doc())!;
      expect(b.addons, isEmpty);
      expect(b.pickup, isNull);
      expect(b.totalVnd, 1500000);
    });

    test('totalVnd = price + Σ amount', () {
      final b = bookingFromFirestore(
        'b1',
        _doc(
          addons: [
            _line('a1', 1600000),
            _line('a2', 300000, unit: 'per_booking'),
          ],
        ),
      )!;
      expect(b.totalVnd, 1500000 + 1600000 + 300000);
    });

    test('remaining falls back to totalVnd − deposit, not price − deposit', () {
      final b = bookingFromFirestore(
        'b1',
        _doc(addons: [_line('a1', 500000)], deposit: 600000),
      )!;
      expect(b.remaining, 1500000 + 500000 - 600000);
    });
  });

  group('createBooking add-on payload', () {
    late _MockCallable callable;
    late FirestoreBookingRepository repo;

    setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

    setUp(() {
      final functions = _MockFunctions();
      callable = _MockCallable();
      when(() => functions.httpsCallable(any(), options: any(named: 'options')))
          .thenReturn(callable);
      final result = _MockResult();
      when(() => result.data).thenReturn({
        ..._doc(),
        'id': 'b1',
        'createdAt': '2026-10-01T00:00:00.000Z',
        'updatedAt': '2026-10-01T00:00:00.000Z',
      });
      when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);
      repo = FirestoreBookingRepository(
        firestore: FakeFirebaseFirestore(),
        functions: functions,
      );
    });

    Map<String, dynamic> sent() =>
        verify(() => callable.call<Object?>(captureAny())).captured.single
            as Map<String, dynamic>;

    test(
      'sends addons [{addonId, qty}], pickup and expectedTotal when given',
      () async {
        await repo.createBooking(
          photographerId: 'p1',
          serviceId: 's1',
          day: '2026-10-20',
          start: '09:00',
          place: const BookingPlace(name: 'Hà Nội'),
          addons: const [AddonPick('a1', 2), AddonPick('a2', 1)],
          pickup: const BookingPlace(name: 'Nội Bài', lat: 21.2, lng: 105.8),
          expectedTotal: 3400000,
        );
        final data = sent();
        expect(data['addons'], [
          {'addonId': 'a1', 'qty': 2},
          {'addonId': 'a2', 'qty': 1},
        ]);
        expect(data['pickup'], {
          'name': 'Nội Bài',
          'point': {'lat': 21.2, 'lng': 105.8},
        });
        expect(data['expectedTotal'], 3400000);
      },
    );

    test('omits addons, pickup and expectedTotal when not given', () async {
      await repo.createBooking(
        photographerId: 'p1',
        serviceId: 's1',
        day: '2026-10-20',
        start: '09:00',
        place: const BookingPlace(name: 'Hà Nội'),
      );
      final data = sent();
      expect(data.containsKey('addons'), isFalse);
      expect(data.containsKey('pickup'), isFalse);
      expect(data.containsKey('expectedTotal'), isFalse);
    });
  });

  test(
    'bookingErrorOf maps addon_changed, addon_not_applicable, pickup_required',
    () {
      expect(
        bookingErrorOf(const BookingException('addon_changed')),
        BookingErrorCode.addonChanged,
      );
      expect(
        bookingErrorOf(const BookingException('addon_not_applicable')),
        BookingErrorCode.addonNotApplicable,
      );
      expect(
        bookingErrorOf(const BookingException('pickup_required')),
        BookingErrorCode.pickupRequired,
      );
    },
  );
}
