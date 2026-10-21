import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/features/studio/studio_common.dart';
import 'package:photobooking/features/studio/studio_errors.dart';

/// "Trả việc" on S06.01-member: the assignee hands a studio shoot back
/// before it starts (Decision 14). A red confirmation sheet with an optional
/// reason; the assignee stays on the booking until [studioName] reassigns
/// it ('' reads "Studio"). True once the server took it.
Future<bool> showReturnJobSheet(
  BuildContext context, {
  required Booking booking,
  required String studioName,
}) {
  final l = context.l10n;
  final repo = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(bookingRepositoryProvider);
  final reason = ValueNotifier<String>('');
  return showConfirmSheet(
    context,
    title: l.returnJobTitle,
    body: l.returnJobBody(studioName.isEmpty ? l.providerStudio : studioName),
    content: StudioReasonField(label: l.returnJobReason, value: reason),
    confirmLabel: l.returnJobConfirm,
    keepLabel: l.returnJobKeep,
    danger: true,
    onConfirm: () async {
      try {
        await repo.returnAssignment(
          booking.id,
          reason: reason.value.isEmpty ? null : reason.value,
        );
      } catch (e) {
        if (!context.mounted) rethrow;
        throw StudioFailure(studioFailureText(context, e));
      }
    },
  );
}
