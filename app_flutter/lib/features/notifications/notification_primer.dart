import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/features/notifications/notifications_analytics.dart';

/// Why the primer is shown; the title names the reason (spec S17.03).
sealed class PrimerContext {
  const PrimerContext();
}

/// A customer just paid: "Bật thông báo để biết khi {name} nhận lịch".
class CustomerBookingPrimer extends PrimerContext {
  const CustomerBookingPrimer(this.photographerName);

  final String photographerName;
}

/// A customer sent an instant request (used by the instant plans).
class CustomerInstantPrimer extends PrimerContext {
  const CustomerInstantPrimer();
}

/// A photographer just accepted a booking.
class PhotographerPrimer extends PrimerContext {
  const PhotographerPrimer();
}

String _contextName(PrimerContext c) => switch (c) {
  CustomerBookingPrimer() => 'customer_booking',
  CustomerInstantPrimer() => 'customer_instant',
  PhotographerPrimer() => 'photographer',
};

/// One sheet at a time, whatever the call site. A flag older than
/// [_inFlightMax] is stale (a route removed without closing never completes
/// its future), so it cannot block the primer for the rest of the session.
DateTime? _inFlightSince;
const _inFlightMax = Duration(minutes: 10);

bool get _inFlight {
  final since = _inFlightSince;
  return since != null && DateTime.now().difference(since) < _inFlightMax;
}

/// Tests that end with the sheet still open clear the flag between cases.
@visibleForTesting
void resetNotificationPrimerState() => _inFlightSince = null;

/// How long a call waits for another route (the caller's own sheet) to close.
const _routeWait = Duration(milliseconds: 100);
const _routeWaitTries = 30;

/// Shows S17.03 when allowed and resolves after the sheet has closed.
/// Never throws: any failure just means no sheet.
///
/// Not asked when the OS permission is granted or permanently denied, within 7
/// days of "Để sau", while another primer is open, or at app start (call it
/// after a meaningful action, once its own sheet or toast is done).
Future<void> maybeAskForNotifications(
  BuildContext context,
  WidgetRef ref,
  PrimerContext c,
) async {
  if (_inFlight) {
    return;
  }
  final mine = _inFlightSince = DateTime.now();
  try {
    final permission = ref.read(notificationPermissionProvider);
    final status = await permission.status();
    if (status == NotificationPermissionStatus.granted ||
        status == NotificationPermissionStatus.permanentlyDenied) {
      return;
    }
    final policy = ref.read(primerPolicyProvider);
    if (!policy.shouldAsk(atAppStart: false)) {
      return;
    }
    // The caller's own sheet may still be closing.
    for (var i = 0; i < _routeWaitTries; i++) {
      if (!context.mounted) {
        return;
      }
      if (ModalRoute.of(context)?.isCurrent ?? true) {
        break;
      }
      await Future<void>.delayed(_routeWait);
    }
    if (!context.mounted) {
      return;
    }
    final log = ref.read(notificationsAnalyticsProvider);
    // Read after the grant, from the container: the registration provider may
    // be rebuilt while the OS dialog is up.
    final container = ProviderScope.containerOf(context);
    final name = _contextName(c);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final enabledText = context.l10n.primerEnabled;
    log('notification_primer_shown', {'context': name});
    final enabling = ValueNotifier(false);
    try {
      final enabled = await showAppSheet<bool>(
        context,
        builder: (sheet) => _PrimerSheet(
          context: c,
          enabling: enabling,
          onLater: () => Navigator.of(sheet).pop(false),
          onEnable: () async {
            if (enabling.value) {
              return;
            }
            enabling.value = true;
            log('notification_primer_enable', {'context': name});
            var granted = false;
            try {
              granted =
                  await permission.request() ==
                  NotificationPermissionStatus.granted;
            } on Object {
              granted = false;
            }
            log('notification_os_result', {'granted': granted});
            if (granted) {
              unawaited(container.read(pushRegistrationProvider).refresh());
              messenger
                ?..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(enabledText)));
            }
            if (sheet.mounted) {
              Navigator.of(sheet).pop(granted);
            }
          },
        ),
      );
      // "Để sau", a drag, a tap outside, Back, or a refusal: ask again in 7
      // days.
      if (enabled != true) {
        if (enabled == null || enabled == false) {
          log('notification_primer_later', {'context': name});
        }
        await policy.later();
      }
    } finally {
      enabling.dispose();
    }
  } on Object {
    // A primer that cannot be shown is just not shown.
  } finally {
    if (_inFlightSince == mine) {
      _inFlightSince = null;
    }
  }
}

class _PrimerSheet extends StatelessWidget {
  const _PrimerSheet({
    required this.context,
    required this.enabling,
    required this.onEnable,
    required this.onLater,
  });

  final PrimerContext context;
  final ValueNotifier<bool> enabling;
  final VoidCallback onEnable;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext buildContext) {
    final l = buildContext.l10n;
    final title = switch (context) {
      CustomerBookingPrimer(:final photographerName) =>
        l.primerTitleCustomerBooking(photographerName),
      CustomerInstantPrimer() => l.primerTitleCustomerInstant,
      PhotographerPrimer() => l.primerTitlePhotographer,
    };
    return ScreenCode(
      ScreenCodes.notificationPermission,
      child: ValueListenableBuilder<bool>(
        valueListenable: enabling,
        builder: (_, busy, _) => PopScope(
          // Back is "Để sau", but not while the OS dialog is up.
          canPop: !busy,
          // Scrolls when large text or a small screen makes it taller than the
          // sheet.
          child: SingleChildScrollView(
            child: PermissionPrimer(
              title: title,
              benefits: [
                PrimerBenefit(AppIcons.check, l.primerBenefit1),
                PrimerBenefit(AppIcons.calendar, l.primerBenefit2),
                PrimerBenefit(AppIcons.chat, l.primerBenefit3),
              ],
              note: l.primerNote,
              enabling: busy,
              onEnable: onEnable,
              onLater: onLater,
            ),
          ),
        ),
      ),
    );
  }
}
