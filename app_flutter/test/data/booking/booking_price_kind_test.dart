import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/booking/booking.dart';

Map<String, dynamic> _doc(Map<String, Object?> snapshot) => {
  'customerId': 'c1',
  'photographerId': 'p1',
  'serviceId': 's1',
  'serviceSnapshot': {
    'name': 'Gói',
    'price': 2500000,
    'durationMinutes': 120,
    ...snapshot,
  },
  'day': '2027-02-06',
  'start': '09:00',
  'end': '11:00',
  'place': {'name': 'Hà Nội'},
  'status': 'requested',
  'deposit': 1000000,
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 6)),
  'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 6)),
};

void main() {
  group('BookingServiceSnapshot priceKind and ruleName', () {
    test('a rule price carries its kind and name', () {
      final b = bookingFromFirestore(
        'b1',
        _doc({'priceKind': 'rule', 'ruleName': 'Tết Nguyên đán'}),
      )!;

      expect(b.serviceSnapshot.price, 2500000);
      expect(b.serviceSnapshot.priceKind, PriceKind.rule);
      expect(b.serviceSnapshot.ruleName, 'Tết Nguyên đán');
    });

    test('old bookings read as base without a rule name', () {
      final b = bookingFromFirestore('b1', _doc({}))!;

      expect(b.serviceSnapshot.priceKind, PriceKind.base);
      expect(b.serviceSnapshot.ruleName, isNull);
    });

    test('an unknown kind reads as base', () {
      final b = bookingFromFirestore('b1', _doc({'priceKind': 'surge'}))!;

      expect(b.serviceSnapshot.priceKind, PriceKind.base);
    });

    test('json keeps the fields; base is the default', () {
      final json = {
        'name': 'Gói',
        'price': 2500000,
        'durationMinutes': 60,
        'priceKind': 'rule',
        'ruleName': 'Cuối tuần',
      };
      final s = BookingServiceSnapshot.fromJson(json);

      expect(s.priceKind, PriceKind.rule);
      expect(s.toJson()['priceKind'], 'rule');
      expect(s.toJson()['ruleName'], 'Cuối tuần');
      expect(
        const BookingServiceSnapshot(
          name: 'Gói',
          price: 1,
          durationMinutes: 60,
        ).priceKind,
        PriceKind.base,
      );
    });
  });
}
