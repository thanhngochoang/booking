// S06.03: the photographer declines a new request.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';

/// Opens the decline confirmation for [booking] over core's
/// [showConfirmSheet]. Returns true after the server accepted the decline.
Future<bool?> showDeclineSheet(
  BuildContext context, {
  required Booking booking,
  required String customerName,
}) {
  final l10n = context.l10n;
  final repo = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(bookingRepositoryProvider);
  return showConfirmSheet(
    context,
    title: l10n.declineTitle(customerName),
    confirmLabel: l10n.declineConfirm,
    keepLabel: l10n.declineBack,
    danger: true,
    onConfirm: () => repo.transitionBooking(
      bookingId: booking.id,
      action: BookingAction.decline.code,
    ),
  );
}
