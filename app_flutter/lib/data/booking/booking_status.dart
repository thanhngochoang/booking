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
  completed,
  reviewed,
}

/// The status for a stored code (`BookingStatus.name`); null when [code] is
/// missing or unknown.
BookingStatus? bookingStatusFromCode(String? code) {
  for (final s in BookingStatus.values) {
    if (s.name == code) return s;
  }
  return null;
}

extension BookingStatusX on BookingStatus {
  Color get color => switch (this) {
    BookingStatus.draft || BookingStatus.requested => AppColors.bookingWaiting,
    BookingStatus.accepted => AppColors.bookingAccepted,
    BookingStatus.declined ||
    BookingStatus.cancelled ||
    BookingStatus.expired => AppColors.bookingDenied,
    BookingStatus.upcoming => AppColors.bookingOpened,
    BookingStatus.completed ||
    BookingStatus.reviewed => AppColors.bookingClosed,
  };

  /// Text color on top of [color]; the warning yellow needs dark text.
  Color get onColor => this == BookingStatus.upcoming
      ? AppColors.foreground
      : AppColors.foregroundInverse;

  String label(AppLocalizations l) => switch (this) {
    BookingStatus.draft || BookingStatus.requested => l.statusRequested,
    BookingStatus.accepted => l.statusAccepted,
    BookingStatus.declined => l.statusDeclined,
    BookingStatus.expired => l.statusExpired,
    BookingStatus.cancelled => l.statusCancelled,
    BookingStatus.upcoming => l.statusUpcoming,
    BookingStatus.completed => l.statusCompleted,
    BookingStatus.reviewed => l.statusReviewed,
  };
}
