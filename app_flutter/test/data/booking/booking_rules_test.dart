import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/booking/booking_status.dart';

void main() {
  group('BookingRules', () {
    test('computeDeposit calculates 30% floor and exact balance', () {
      final res1 = BookingRules.computeDeposit(1000000);
      expect(res1.deposit, 300000);
      expect(res1.remaining, 700000);

      final res2 = BookingRules.computeDeposit(1500000);
      expect(res2.deposit, 450000);
      expect(res2.remaining, 1050000);

      final res3 = BookingRules.computeDeposit(1234567);
      expect(res3.deposit, (1234567 * 0.3).floor());
      expect(res3.deposit + res3.remaining, 1234567);
    });

    test('parseBookingDateTime parses Asia/Ho_Chi_Minh timezone correctly', () {
      final dt = BookingRules.parseBookingDateTime('2026-10-15', '09:30');
      // 09:30 UTC+7 is 02:30 UTC
      expect(dt, DateTime.utc(2026, 10, 15, 2, 30));
    });

    group('computeRefundPercent', () {
      final startsAt = DateTime.utc(2026, 10, 15, 2, 0); // 09:00 VN

      test('photographer or system cancels get 100% refund', () {
        final cancelTime = startsAt.subtract(const Duration(hours: 1));
        expect(
          BookingRules.computeRefundPercent(
            startsAt: startsAt,
            cancelledAt: cancelTime,
            actorRole: 'photographer',
          ),
          100,
        );
        expect(
          BookingRules.computeRefundPercent(
            startsAt: startsAt,
            cancelledAt: cancelTime,
            actorRole: 'system',
          ),
          100,
        );
      });

      test('customer cancels >= 48h before start gets 100%', () {
        final cancelTime = startsAt.subtract(const Duration(hours: 48));
        expect(
          BookingRules.computeRefundPercent(
            startsAt: startsAt,
            cancelledAt: cancelTime,
            actorRole: 'customer',
          ),
          100,
        );
      });

      test('customer cancels 24h..48h before start gets 50%', () {
        final cancelTime = startsAt.subtract(const Duration(hours: 30));
        expect(
          BookingRules.computeRefundPercent(
            startsAt: startsAt,
            cancelledAt: cancelTime,
            actorRole: 'customer',
          ),
          50,
        );
      });

      test('customer cancels < 24h before start gets 0%', () {
        final cancelTime = startsAt.subtract(const Duration(hours: 10));
        expect(
          BookingRules.computeRefundPercent(
            startsAt: startsAt,
            cancelledAt: cancelTime,
            actorRole: 'customer',
          ),
          0,
        );
      });
    });

    group('S05.01 Tab grouping', () {
      Booking makeBooking({
        required String id,
        required BookingStatus status,
        required String day,
        required String start,
        required DateTime createdAt,
        required DateTime updatedAt,
      }) {
        return Booking(
          id: id,
          customerId: 'c1',
          photographerId: 'p1',
          serviceId: 's1',
          serviceSnapshot: const BookingServiceSnapshot(
            name: 'Gói',
            price: 1000000,
            durationMinutes: 60,
          ),
          day: day,
          start: start,
          end: '10:00',
          place: const BookingPlace(name: 'Hà Nội'),
          status: status,
          deposit: 300000,
          remaining: 700000,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
      }

      test('tabForBooking categorizes statuses properly', () {
        final bDraft = makeBooking(
          id: 'b0',
          status: BookingStatus.draft,
          day: '2026-10-15',
          start: '09:00',
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        );
        expect(BookingRules.tabForBooking(bDraft), isNull);

        final bReq = makeBooking(
          id: 'b1',
          status: BookingStatus.requested,
          day: '2026-10-15',
          start: '09:00',
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        );
        expect(BookingRules.tabForBooking(bReq), BookingTab.pending);

        final bAcc = makeBooking(
          id: 'b2',
          status: BookingStatus.accepted,
          day: '2026-10-15',
          start: '09:00',
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        );
        expect(BookingRules.tabForBooking(bAcc), BookingTab.upcoming);

        final bUp = makeBooking(
          id: 'b3',
          status: BookingStatus.upcoming,
          day: '2026-10-15',
          start: '09:00',
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        );
        expect(BookingRules.tabForBooking(bUp), BookingTab.upcoming);

        final bComp = makeBooking(
          id: 'b4',
          status: BookingStatus.completed,
          day: '2026-10-15',
          start: '09:00',
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        );
        expect(BookingRules.tabForBooking(bComp), BookingTab.history);
      });

      test('groupBookingsByTab groups and sorts', () {
        final b1 = makeBooking(
          id: 'b1',
          status: BookingStatus.accepted,
          day: '2026-10-20',
          start: '08:00',
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        );
        final b2 = makeBooking(
          id: 'b2',
          status: BookingStatus.upcoming,
          day: '2026-10-15',
          start: '08:00',
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        );
        final b3 = makeBooking(
          id: 'b3',
          status: BookingStatus.requested,
          day: '2026-10-25',
          start: '08:00',
          createdAt: DateTime.utc(2026, 10, 2),
          updatedAt: DateTime.utc(2026, 10, 2),
        );
        final bDraft = makeBooking(
          id: 'bd',
          status: BookingStatus.draft,
          day: '2026-10-25',
          start: '08:00',
          createdAt: DateTime.utc(2026, 10, 2),
          updatedAt: DateTime.utc(2026, 10, 2),
        );

        final grouped = BookingRules.groupBookingsByTab([b1, b2, b3, bDraft]);
        expect(grouped[BookingTab.upcoming]?.length, 2);
        // Nearest date first
        expect(grouped[BookingTab.upcoming]?[0].id, 'b2');
        expect(grouped[BookingTab.upcoming]?[1].id, 'b1');

        expect(grouped[BookingTab.pending]?.length, 1);
        expect(grouped[BookingTab.pending]?[0].id, 'b3');

        expect(grouped[BookingTab.history]?.length, 0);
      });
    });

    group('Task 1 Additions', () {
      test('daySlots: 120 minutes → 06:00 … 18:00, 25 slots; 480 → last 12:00; 900 → empty', () {
        final slots120 = daySlots(120);
        expect(slots120.length, 25);
        expect(slots120.first, '06:00');
        expect(slots120.last, '18:00');

        final slots480 = daySlots(480);
        expect(slots480.last, '12:00');

        final slots900 = daySlots(900);
        expect(slots900, isEmpty);
      });

      test('endTimeFor 15:30 + 120 → 17:30', () {
        expect(endTimeFor('15:30', 120), '17:30');
      });

      test('depositFor matches the shared fixture packages/domain/test/fixtures/booking_policy.json', () {
        // Read booking_policy.json
        final file = File('../packages/domain/test/fixtures/booking_policy.json');
        final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final depositCases = jsonMap['depositCases'] as List<dynamic>;

        for (final item in depositCases) {
          final c = item as Map<String, dynamic>;
          final price = c['price'] as int;
          final expectedDeposit = c['deposit'] as int;
          final expectedRemaining = c['remaining'] as int;

          final res = depositFor(price);
          expect(res.deposit, expectedDeposit, reason: 'Failed deposit for price $price');
          expect(res.remaining, expectedRemaining, reason: 'Failed remaining for price $price');
        }
      });

      test('bookingErrorOf maps every server code and network errors', () {
        expect(bookingErrorOf(const BookingException('day_taken')), BookingErrorCode.dayTaken);
        expect(bookingErrorOf(const BookingException('phone_required')), BookingErrorCode.phoneRequired);
        expect(bookingErrorOf(const BookingException('price_changed')), BookingErrorCode.priceChanged);
        expect(bookingErrorOf(const BookingException('not_eligible')), BookingErrorCode.notEligible);
        expect(bookingErrorOf(const BookingException('deadline_passed')), BookingErrorCode.deadlinePassed);
        expect(bookingErrorOf(const BookingException('conflict')), BookingErrorCode.conflict);
        expect(bookingErrorOf(const BookingException('permission_denied')), BookingErrorCode.permissionDenied);
        expect(bookingErrorOf(const BookingException('permission-denied')), BookingErrorCode.permissionDenied);
        expect(bookingErrorOf(const BookingException('not_found')), BookingErrorCode.notFound);
        expect(bookingErrorOf(const BookingException('not-found')), BookingErrorCode.notFound);
        expect(bookingErrorOf(const BookingException('invalid_argument')), BookingErrorCode.invalidArgument);
        expect(bookingErrorOf(const BookingException('invalid-argument')), BookingErrorCode.invalidArgument);
        expect(bookingErrorOf(const BookingException('unavailable')), BookingErrorCode.network);
        expect(bookingErrorOf(const BookingException('network')), BookingErrorCode.network);
        expect(bookingErrorOf(const SocketException('Connection refused')), BookingErrorCode.network);
        expect(bookingErrorOf(const BookingException('unknown_code_foo')), BookingErrorCode.unknown);
        expect(bookingErrorOf(Exception('Random exception')), BookingErrorCode.unknown);
      });
    });
  });
}
