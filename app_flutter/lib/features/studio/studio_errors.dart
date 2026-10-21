import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/studio/studio_repository.dart';

/// What a refused studio call means to the user (Contract §L10n errors);
/// codes without their own text read "Chưa thực hiện được. Thử lại."
String studioErrorText(BuildContext context, String code) {
  final l = context.l10n;
  return switch (code) {
    'membership_conflict' => l.studioErr_membership_conflict,
    'cooldown' => l.studioErr_cooldown,
    'member_busy' => l.studioErr_member_busy,
    'studio_full' => l.studioErr_studio_full,
    'rate_limited' => l.studioErr_rate_limited,
    'not_accepting_orders' => l.studioErr_not_accepting_orders,
    'day_taken' => l.studioErr_day_taken,
    'conflict' => l.studioErr_conflict,
    _ => l.studioErr_generic,
  };
}

/// The text of any failure of a studio call: the own text of a
/// [StudioError] or of a studio booking call's [BookingException]
/// (`assignBooking`, `declineAssigneeChange`, `returnAssignment`), else the
/// generic line.
String studioFailureText(BuildContext context, Object error) =>
    studioErrorText(context, switch (error) {
      StudioError(:final code) => code,
      BookingException(:final code) => code,
      _ => '',
    });

/// Thrown inside a [showConfirmSheet] action so the sheet's SnackBar shows
/// [text] as it is.
class StudioFailure implements Exception {
  const StudioFailure(this.text);
  final String text;

  @override
  String toString() => text;
}

/// Runs [action] and shows its refusal in a SnackBar; true when it went
/// through.
Future<bool> runStudioAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    return true;
  } catch (e) {
    if (context.mounted) {
      // The newest refusal replaces an older one still on screen.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(studioFailureText(context, e))));
    }
    return false;
  }
}

/// An action the app already knows the server would refuse (a member who
/// still has studio shoots): a sheet that says why, with only "Đóng".
Future<void> showStudioBlockedSheet(
  BuildContext context, {
  required String title,
  required String body,
}) {
  final l = context.l10n;
  return showAppSheet<void>(
    context,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final secondary = theme.brightness == Brightness.dark
          ? AppColorsDark.foregroundSecondary
          : AppColors.foregroundSecondary;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          0,
          AppSpace.s4,
          AppSpace.s4,
        ),
        child: Column(
          key: const Key('studio-blocked-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpace.s4),
            AppButton.outline(
              l.studioSheetClose,
              key: const Key('studio-blocked-close'),
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      );
    },
  );
}
