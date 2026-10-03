// User-facing text for a refused or failed booking transition.
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// The SnackBar line for [error] thrown by `transitionBooking`.
String bookingErrorText(Object error, AppLocalizations l10n) =>
    switch (bookingErrorOf(error)) {
      BookingErrorCode.deadlinePassed => l10n.detailErrorExpired,
      BookingErrorCode.notEligible => l10n.detailErrorNotEligible,
      BookingErrorCode.conflict => l10n.detailErrorConflict,
      _ => l10n.detailErrorNetwork,
    };

/// An error whose [toString] is already the friendly message: core's
/// confirmation sheet shows `error.toString()` in its SnackBar.
class BookingActionError implements Exception {
  const BookingActionError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Runs [action] and rethrows any failure as a [BookingActionError] with
/// the text of [bookingErrorText], for use as a sheet's `onConfirm`.
Future<void> withBookingErrorText(
  AppLocalizations l10n,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    throw BookingActionError(bookingErrorText(e, l10n));
  }
}
