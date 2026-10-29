// lib/data/events/event_registration.dart
import 'package:flutter/foundation.dart';

import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/organizer/organizer.dart';

enum RegistrationStatus {
  held,
  paid,
  cancelled,
  refunded;

  String get code => name;

  static RegistrationStatus fromCode(String? code) => values.firstWhere(
    (s) => s.name == code,
    orElse: () => RegistrationStatus.cancelled,
  );

  /// Takes a seat: `held` (10 minutes) or `paid`.
  bool get isActive => this == held || this == paid;
}

/// The gateway state of a ticket's refund (`registrations.refundStatus`):
/// "Đang hoàn" until it is [done]; [failed] stays with staff, so the money
/// is still on its way for the customer.
enum TicketRefundStatus {
  pending('pending'),
  awaitingAccount('awaiting_account'),
  done('done'),
  failed('failed');

  const TicketRefundStatus(this.code);

  final String code;

  /// Null for a missing or unknown code (no refund).
  static TicketRefundStatus? fromCode(String? code) =>
      values.where((s) => s.code == code).firstOrNull;
}

/// The event as it was when the ticket was bought (S11.04 shows it without
/// reading the event).
@immutable
class EventTicketSnapshot {
  const EventTicketSnapshot({
    required this.title,
    required this.type,
    required this.startsAt,
    required this.endsAt,
    this.locationName,
    this.lat,
    this.lng,
    this.coverUrl,
  });

  final String title;
  final EventType type;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? locationName;
  final double? lat;
  final double? lng;
  final String? coverUrl;
}

@immutable
class EventRegistration {
  const EventRegistration({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.userName,
    required this.ticketCode,
    required this.quantity,
    required this.amount,
    required this.status,
    required this.event,
    required this.createdAt,
    this.userAvatarUrl,
    this.paymentId,
    this.holdExpiresAt,
    this.checkedInAt,
    this.cancelledAt,
    this.refundPercent,
    this.contactEligible = false,
    this.refundDue = false,
    this.refundStatus,
    this.disputeId,
    this.visitDay,
    this.items = const [],
    this.bookingId,
    this.gateCheckedInAt,
    this.ticketCodeLast4 = '',
  });

  final String id;
  final String eventId;
  final String userId;
  final String userName;

  /// Legacy `VE-XXXX-MMDD`; empty until the registration is `paid`, and
  /// always empty on a registration made after S30 (the code is in
  /// `private/pass`, Decision 8).
  final String ticketCode;

  /// S30 entry tickets: the visit day (`yyyy-MM-dd`), the priced lines, the
  /// booking they came with, and the venue gate's scan of an event ticket.
  final String? visitDay;
  final List<EntryLine> items;
  final String? bookingId;
  final DateTime? gateCheckedInAt;

  /// The last 4 random characters of the pass (S12.03 attendee list).
  final String ticketCodeLast4;
  final String? userAvatarUrl;
  final String? paymentId;
  final int quantity;

  /// Integer VND; 0 for a free event.
  final int amount;
  final RegistrationStatus status;
  final DateTime? holdExpiresAt;
  final DateTime? checkedInAt;
  final DateTime? cancelledAt;
  final int? refundPercent;

  /// True only for a paid ticket: the host may then see the attendee's phone
  /// and the attendee unlocks the host's phone/Zalo/WhatsApp (owner decision
  /// O3). A free registration is never contact-eligible, so no screen may show
  /// a phone number for it.
  final bool contactEligible;

  /// The event was cancelled while this ticket's money was held: the 100%
  /// refund is on its way ("Đang hoàn" until the status is `refunded`).
  final bool refundDue;

  /// The refund of this ticket's money, once the server made one (a refunded
  /// ticket, or a cancelled one whose payment arrived after the hold). Null
  /// on an older refunded ticket: treated as done.
  final TicketRefundStatus? refundStatus;

  /// The open or resolved dispute of this ticket (S18, server mirror).
  final String? disputeId;
  final EventTicketSnapshot event;
  final DateTime createdAt;

  bool get isActive => status.isActive;

  /// An entry ticket (S30.05 / S04.03-entry), sold per visit day.
  bool get isEntry => visitDay != null;

  /// What the manager's list shows: [ticketCodeLast4], or the last 4 of a
  /// legacy code.
  String get codeLast4 => ticketCodeLast4.isNotEmpty
      ? ticketCodeLast4
      : ticketCode.length >= 4
      ? ticketCode.substring(ticketCode.length - 4)
      : '';
  bool get isFree => amount == 0;
  bool get isCheckedIn => checkedInAt != null;

  /// A `held` registration whose 10 minutes ran out (the server releases it
  /// within a minute; until then the app already treats it as expired).
  bool holdExpired(DateTime now) =>
      status == RegistrationStatus.held &&
      holdExpiresAt != null &&
      !now.isBefore(holdExpiresAt!);
}
