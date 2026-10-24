// S18.01 entry API (#142): who may open a dispute, until when, and the sheet
// itself. S05.02, S11.04 and S05.06 (through `/b/:id/dispute?from=delivery`)
// call these; the server decides (`openDispute`), these only decide what to
// show.
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/features/disputes/open_dispute_controller.dart';
import 'package:photobooking/features/disputes/open_dispute_sheet.dart';

export 'package:photobooking/data/disputes/dispute.dart' show DisputeOrigin;

/// Hours of the dispute window (the domain's `DISPUTE_WINDOW_HOURS`).
const disputeWindowHours = 24;

/// What a dispute is about: a booking, or a paid event ticket.
sealed class DisputeSubject {
  const DisputeSubject();

  const factory DisputeSubject.booking(String bookingId) =
      BookingDisputeSubject;

  const factory DisputeSubject.ticket({
    required String eventId,
    required String registrationId,
  }) = TicketDisputeSubject;
}

class BookingDisputeSubject extends DisputeSubject {
  const BookingDisputeSubject(this.bookingId);
  final String bookingId;
}

class TicketDisputeSubject extends DisputeSubject {
  const TicketDisputeSubject({
    required this.eventId,
    required this.registrationId,
  });
  final String eventId;
  final String registrationId;
}

/// What the dispute is about, in words ("Minh Trí · Chân dung 2 giờ",
/// "T7 12/10 · 15:30–17:30"). The sheet sits over the card that shows it, so
/// it is read out to screen readers only (the barrier hides the card).
@immutable
class DisputeSubjectSummary {
  const DisputeSubjectSummary({
    required this.title,
    required this.subtitle,
    this.thumbUrl,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String? thumbUrl;
  final String? badge;
}

/// Opens S18.01. Resolves to the new dispute id after a successful submit,
/// null when closed.
Future<String?> showOpenDisputeSheet(
  BuildContext context, {
  required DisputeSubject subject,
  required DisputeSubjectSummary summary,
  required DateTime closesAt,
  DisputeOrigin origin = DisputeOrigin.booking,
}) {
  // One id per sheet: the evidence lives under it and a retried submit is
  // answered with the same dispute (Decision 4).
  final args = OpenDisputeArgs(disputeId: newUlid(), subject: subject);
  return showAppSheet<String>(
    context,
    // The header handles the swipe (it asks first when something was typed).
    enableDrag: false,
    builder: (_) => ScreenCode(
      ScreenCodes.openDispute,
      label: origin == DisputeOrigin.deliveryCheck ? 'delivery' : null,
      child: OpenDisputeSheet(
        args: args,
        summary: summary,
        closesAt: closesAt,
        origin: origin,
      ),
    ),
  );
}

/// Hours left (rounded up), null once [closesAt] is reached. Pure.
int? disputeHoursLeft(DateTime closesAt, DateTime now) {
  final left = closesAt.difference(now);
  if (left <= Duration.zero) {
    return null;
  }
  const hour = Duration.microsecondsPerHour;
  return (left.inMicroseconds + hour - 1) ~/ hour;
}

bool _holdsMoney(EscrowStatus? s) =>
    s == EscrowStatus.held || s == EscrowStatus.partiallyRefunded;

/// When the customer's dispute window on [b] closes, or null when there is
/// none. Mirrors the server's `disputeWindow` (Decision 2): `shot` → 24 h
/// after the shoot; `approved` → the end of the delivery check; `completed`
/// / `reviewed` with money still held (a payment without milestones) → 24 h
/// after completion. Only while money is held and no dispute is linked.
DateTime? bookingDisputeClosesAt(Booking b) {
  if (b.disputeId != null || !_holdsMoney(b.escrowStatus)) {
    return null;
  }
  return switch (b.status) {
    BookingStatus.shot => b.shotAt?.add(
      const Duration(hours: disputeWindowHours),
    ),
    BookingStatus.approved => b.checkUntil,
    BookingStatus.completed || BookingStatus.reviewed => b.completedAt?.add(
      const Duration(hours: disputeWindowHours),
    ),
    _ => null,
  };
}

/// The reasons and copy S18.01 uses for [b]: the delivery check ("Báo vấn
/// đề với ảnh gốc") once the photos are approved, else the shoot.
DisputeOrigin bookingDisputeOrigin(Booking b) =>
    b.status == BookingStatus.approved
    ? DisputeOrigin.deliveryCheck
    : DisputeOrigin.booking;

/// When the dispute window of a paid ticket closes: 24 h after the event
/// ends (check-in not required, Decision 2). Null for a free, unpaid or
/// already disputed ticket.
DateTime? ticketDisputeClosesAt(EventRegistration r) {
  if (r.status != RegistrationStatus.paid ||
      r.amount <= 0 ||
      r.disputeId != null) {
    return null;
  }
  return r.event.endsAt.add(const Duration(hours: disputeWindowHours));
}

/// S05.02 `S05.02-disputed`: "Đang khiếu nại" / "Khiếu nại đã có kết quả" →
/// S18.02. Read from the booking itself (no extra read): the dispute freezes
/// the money (`escrowStatus: disputed`) and the resolution restores it.
class DisputeBanner extends StatelessWidget {
  const DisputeBanner({super.key, required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    final iconColor = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final link = dark ? AppColorsDark.primary : AppColors.primary;
    final radius = BorderRadius.circular(AppRadius.md);
    final title = open ? l.disputeBannerOpen : l.disputeBannerResolved;
    return Semantics(
      button: true,
      label: open ? '$title. ${l.disputeBannerOpenBody}' : title,
      hint: l.disputeBannerView,
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: radius,
        child: InkWell(
          key: const Key('dispute-banner'),
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpace.s12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s3,
                vertical: AppSpace.s2h,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: AppIcon(AppIcons.flag, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: AppText.chip,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            color: fg,
                          ),
                        ),
                        if (open)
                          Text(
                            l.disputeBannerOpenBody,
                            style: TextStyle(
                              fontSize: AppText.chip,
                              height: 1.35,
                              color: fg,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Text(
                    l.disputeBannerView,
                    style: TextStyle(
                      fontSize: AppText.chip,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: link,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
