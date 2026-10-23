import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/features/studio/studio_common.dart';
import 'package:photobooking/features/studio/studio_errors.dart';

/// "Từ chối đổi" on S06.01-studio: the studio keeps the assignee and says
/// why (Decision 13). A red confirmation sheet whose button stays off until
/// the reason (required, up to 300 characters) is written; the customer
/// sees it and may then cancel with a full refund. True once the server
/// took the answer.
Future<bool> showDeclineChangeSheet(BuildContext context, Booking booking) {
  final l = context.l10n;
  final repo = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(bookingRepositoryProvider);
  // Written by the field, read by the button and onConfirm.
  final reason = ValueNotifier<String>('');
  final valid = ValueNotifier<bool>(false);
  reason.addListener(() => valid.value = reason.value.isNotEmpty);
  // Disposed once the sheet is closed (removeListener after dispose is allowed
  // for the widgets still on screen during the exit animation).
  return showConfirmSheet(
    context,
    title: l.changeDeclineTitle,
    body: l.changeDeclineBody,
    content: StudioReasonField(label: l.changeDeclineReason, value: reason),
    confirmLabel: l.changeDeclineConfirm,
    keepLabel: l.changeDeclineKeep,
    danger: true,
    confirmEnabled: valid,
    onConfirm: () async {
      try {
        await repo.declineChange(booking.id, reason.value);
      } catch (e) {
        if (!context.mounted) rethrow;
        throw StudioFailure(studioFailureText(context, e));
      }
    },
  ).whenComplete(() {
    reason.dispose();
    valid.dispose();
  });
}
