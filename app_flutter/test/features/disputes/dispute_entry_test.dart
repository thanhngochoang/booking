import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/features/disputes/dispute_entry.dart';

import '../../support/booking_fixtures.dart';

final _now = DateTime.utc(2026, 10, 20, 8);

Booking _booking(
  BookingStatus status, {
  EscrowStatus? escrow = EscrowStatus.held,
  DateTime? shotAt,
  DateTime? checkUntil,
  DateTime? completedAt,
  String? disputeId,
}) => makeTestBooking(
  id: 'b1',
  status: status,
  escrowStatus: escrow,
  completedAt: completedAt,
).copyWith(shotAt: shotAt, checkUntil: checkUntil, disputeId: disputeId);

EventRegistration _ticket({
  int amount = 300000,
  RegistrationStatus status = RegistrationStatus.paid,
  DateTime? endsAt,
  String? disputeId,
  DateTime? checkedInAt,
}) {
  final end = endsAt ?? _now.subtract(const Duration(hours: 3));
  return EventRegistration(
    id: 'r1',
    eventId: 'ev1',
    userId: 'c1',
    userName: 'Lan',
    ticketCode: 'VE-1',
    quantity: 1,
    amount: amount,
    status: status,
    checkedInAt: checkedInAt,
    paymentId: amount > 0 ? 'pay1' : null,
    disputeId: disputeId,
    event: EventTicketSnapshot(
      title: 'Photo walk',
      type: EventType.photoWalk,
      startsAt: end.subtract(const Duration(hours: 2)),
      endsAt: end,
    ),
    createdAt: _now.subtract(const Duration(days: 3)),
  );
}

void main() {
  test('disputeHoursLeft rounds up and is null at closesAt', () {
    final closesAt = _now.add(const Duration(hours: 17, minutes: 1));
    expect(disputeHoursLeft(closesAt, _now), 18);
    expect(disputeHoursLeft(_now.add(const Duration(hours: 18)), _now), 18);
    expect(disputeHoursLeft(_now.add(const Duration(seconds: 1)), _now), 1);
    expect(disputeHoursLeft(_now, _now), isNull);
    expect(
      disputeHoursLeft(_now.subtract(const Duration(minutes: 1)), _now),
      isNull,
    );
  });

  group('bookingDisputeClosesAt (the server windows, Decision 2)', () {
    test('shot: 24 h after the shoot, origin booking', () {
      final b = _booking(
        BookingStatus.shot,
        shotAt: _now.subtract(const Duration(hours: 6)),
      );
      expect(bookingDisputeClosesAt(b), _now.add(const Duration(hours: 18)));
      expect(bookingDisputeOrigin(b), DisputeOrigin.booking);
    });

    test('approved: until the end of the delivery check, origin delivery', () {
      final until = _now.add(const Duration(hours: 47));
      final b = _booking(BookingStatus.approved, checkUntil: until);
      expect(bookingDisputeClosesAt(b), until);
      expect(bookingDisputeOrigin(b), DisputeOrigin.deliveryCheck);
    });

    test('completed with held escrow: 24 h after completion', () {
      final b = _booking(
        BookingStatus.completed,
        completedAt: _now.subtract(const Duration(hours: 2)),
      );
      expect(bookingDisputeClosesAt(b), _now.add(const Duration(hours: 22)));
    });

    test('bookingDisputeClosesAt is null on a completed booking with deliveryCancel or approvedAt even with escrow held; a legacy completed booking keeps completedAt + 24 h', () {
      final completedAt = _now.subtract(const Duration(hours: 2));
      final legacy = _booking(
        BookingStatus.completed,
        completedAt: completedAt,
        escrow: EscrowStatus.held,
      );
      expect(bookingDisputeClosesAt(legacy), _now.add(const Duration(hours: 22)));

      final withApproved = legacy.copyWith(approvedAt: completedAt);
      expect(bookingDisputeClosesAt(withApproved), isNull);

      final withLateCancel = legacy.copyWith(
        escrowStatus: EscrowStatus.partiallyRefunded,
        deliveryCancel: DeliveryCancel(
          at: completedAt,
          dueAt: completedAt.subtract(const Duration(days: 1)),
          refundedAmount: 500000,
        ),
      );
      expect(bookingDisputeClosesAt(withLateCancel), isNull);
    });

    test('a resolved shoot dispute leaves the delivery window open once '
        'approved; an open one or a shot booking hides it', () {
      final until = _now.add(const Duration(hours: 47));
      // Resolved (escrow no longer `disputed`), delivery still held.
      expect(
        bookingDisputeClosesAt(
          _booking(BookingStatus.approved, checkUntil: until, disputeId: 'd1'),
        ),
        until,
      );
      // The linked dispute is still open.
      expect(
        bookingDisputeClosesAt(
          _booking(
            BookingStatus.approved,
            checkUntil: until,
            disputeId: 'd1',
            escrow: EscrowStatus.disputed,
          ),
        ),
        isNull,
      );
      // Still `shot`: the resolved dispute was the shoot one.
      expect(
        bookingDisputeClosesAt(
          _booking(
            BookingStatus.shot,
            shotAt: _now.subtract(const Duration(hours: 2)),
            disputeId: 'd1',
          ),
        ),
        isNull,
      );
    });

    test('nothing held, a dispute already linked, or another state → null', () {
      final done = _now.subtract(const Duration(hours: 2));
      expect(
        bookingDisputeClosesAt(
          _booking(
            BookingStatus.completed,
            completedAt: done,
            escrow: EscrowStatus.released,
          ),
        ),
        isNull,
      );
      expect(
        bookingDisputeClosesAt(
          _booking(BookingStatus.completed, completedAt: done, disputeId: 'd1'),
        ),
        isNull,
      );
      expect(bookingDisputeClosesAt(_booking(BookingStatus.upcoming)), isNull);
      expect(bookingDisputeClosesAt(_booking(BookingStatus.delivered)), isNull);
      expect(bookingDisputeClosesAt(_booking(BookingStatus.shot)), isNull);
    });
  });

  group('ticketDisputeClosesAt', () {
    test('a paid ticket: 24 h after the event ends, check-in or not', () {
      final end = _now.subtract(const Duration(hours: 3));
      final closesAt = end.add(const Duration(hours: 24));
      expect(ticketDisputeClosesAt(_ticket(endsAt: end)), closesAt);
      expect(
        ticketDisputeClosesAt(_ticket(endsAt: end, checkedInAt: end)),
        closesAt,
      );
    });

    test('free, not paid, or already disputed → null', () {
      expect(ticketDisputeClosesAt(_ticket(amount: 0)), isNull);
      expect(
        ticketDisputeClosesAt(_ticket(status: RegistrationStatus.refunded)),
        isNull,
      );
      expect(ticketDisputeClosesAt(_ticket(disputeId: 'd1')), isNull);
    });
  });
}
