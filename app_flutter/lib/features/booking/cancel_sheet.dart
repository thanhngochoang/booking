// S05.03: cancel a booking (customer) and its photographer variant.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';

/// Opens the cancel confirmation for [booking] over core's [showConfirmSheet].
/// Returns true after the server accepted the cancel.
Future<bool?> showCancelSheet(
  BuildContext context, {
  required Booking booking,
  required BookingRole role,
  required String counterpartName,
}) {
  final l10n = context.l10n;
  final repo = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(bookingRepositoryProvider);
  return showConfirmSheet(
    context,
    title: role == BookingRole.customer
        ? l10n.cancelTitle
        : l10n.cancelTitlePhotographer(counterpartName),
    confirmLabel: l10n.cancelConfirm,
    keepLabel: l10n.cancelKeep,
    danger: true,
    onConfirm: () => repo.transitionBooking(
      bookingId: booking.id,
      action: BookingAction.cancel.code,
    ),
  );
}
