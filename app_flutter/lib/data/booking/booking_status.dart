import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

enum BookingStatus {
  draft,
  requested,
  accepted,
  declined,
  expired,
  cancelled,
  upcoming,

  /// S30: the photographer scanned the customer's pass; the shoot is on.
  shooting,
  shot,
  delivered,
  revisionRequested,
  approved,
  completed,
  reviewed,
}

/// The status for a stored code (`BookingStatus.name`); null when [code] is
/// missing or unknown.
BookingStatus? bookingStatusFromCode(String? code) {
  if (code == 'revision_requested') return BookingStatus.revisionRequested;
  for (final s in BookingStatus.values) {
    if (s.name == code) return s;
  }
  return null;
}

extension BookingStatusX on BookingStatus {
  Color get color => switch (this) {
    BookingStatus.draft ||
    BookingStatus.requested ||
    BookingStatus.delivered => AppColors.bookingWaiting,
    BookingStatus.accepted ||
    BookingStatus.approved => AppColors.bookingAccepted,
    BookingStatus.declined ||
    BookingStatus.cancelled ||
    BookingStatus.expired => AppColors.bookingDenied,
    BookingStatus.upcoming ||
    BookingStatus.shooting ||
    BookingStatus.shot ||
    BookingStatus.revisionRequested => AppColors.bookingOpened,
    BookingStatus.completed ||
    BookingStatus.reviewed => AppColors.bookingClosed,
  };

  /// Text color on top of [color]; the warning yellow needs dark text.
  Color get onColor =>
      (this == BookingStatus.upcoming ||
          this == BookingStatus.shooting ||
          this == BookingStatus.shot ||
          this == BookingStatus.revisionRequested)
      ? AppColors.foreground
      : AppColors.foregroundInverse;

  String label(AppLocalizations l) => switch (this) {
    BookingStatus.draft || BookingStatus.requested => l.statusRequested,
    BookingStatus.accepted => l.statusAccepted,
    BookingStatus.declined => l.statusDeclined,
    BookingStatus.expired => l.statusExpired,
    BookingStatus.cancelled => l.statusCancelled,
    BookingStatus.upcoming => l.statusUpcoming,
    BookingStatus.shooting => l.statusShooting,
    BookingStatus.shot => l.statusShot,
    BookingStatus.delivered => l.statusDelivered,
    BookingStatus.revisionRequested => l.statusRevisionRequested,
    BookingStatus.approved => l.statusApproved,
    BookingStatus.completed => l.statusCompleted,
    BookingStatus.reviewed => l.statusReviewed,
  };
}
