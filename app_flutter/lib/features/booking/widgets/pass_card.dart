// S05.02-pass "Mã gặp thợ": the customer's meeting pass from 24 h before
// the shoot — the QR, the 8-character code and the entry tickets it
// carries. Tapping it shows the QR full screen at full brightness. The code
// comes from `myPassProvider`, which keeps it on the phone for offline use.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/passes/pass_providers.dart';
import 'package:photobooking/data/passes/pass_repository.dart';

/// The pass shows from this long before the start (spec S05.02-pass).
const passCardLead = Duration(hours: 24);

/// Whether the customer's pass card of [b] is due at [now]: a booking with
/// a pass, still to meet or being shot, from 24 h before its start.
bool showsPassCard(Booking b, DateTime now) =>
    b.hasPass &&
    (b.status == BookingStatus.accepted ||
        b.status == BookingStatus.upcoming ||
        b.status == BookingStatus.shooting) &&
    !now.isBefore(startsAtOf(b).subtract(passCardLead));

/// Entry tickets carried by the pass.
int passTicketCount(Booking b) =>
    b.entry?.items.fold<int>(0, (n, i) => n + i.qty) ?? 0;

class PassCard extends ConsumerWidget {
  const PassCard({
    super.key,
    required this.booking,
    required this.photographerName,
    required this.now,
  });

  final Booking booking;
  final String photographerName;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final code = ref.watch(myPassProvider(PassRef.booking(booking.id))).value;
    if (code == null) return const SizedBox.shrink();
    final shown = passDisplay(code);
    final tickets = passTicketCount(booking);
    final day = parseDayKey(booking.day);
    final dayLabel = booking.day == vnDateKey(now)
        ? l.spotDayToday
        : (day == null ? booking.day : formatDay(day));
    return Semantics(
      button: true,
      label: l.s0502_passOpen,
      child: InkWell(
        key: const Key('pass-card'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => Navigator.of(context).push(
          PageRouteBuilder<void>(
            opaque: false,
            barrierDismissible: true,
            barrierColor: AppColors.scrim,
            pageBuilder: (_, _, _) => PassFullScreen(code: shown),
          ),
        ),
        child: GlassCard(
          highlight: true,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.s0502_passTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            l.s0502_passWhen(
                              dayLabel,
                              booking.start,
                              booking.place.name,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: secondary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.s2),
                    StatusBadge(booking.status),
                  ],
                ),
                const SizedBox(height: AppSpace.s3),
                Row(
                  children: [
                    Hero(
                      tag: 'pass-qr-${booking.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: QrImageView(
                          data: shown,
                          size: 112,
                          backgroundColor: AppColors.surface,
                          padding: const EdgeInsets.all(AppSpace.s2),
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                          semanticsLabel: l.ticketCodeSemantics(shown),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tickets > 0
                                ? l.s0502_passShowGate(photographerName)
                                : l.s0502_passShow(photographerName),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: secondary,
                            ),
                          ),
                          const SizedBox(height: AppSpace.s2),
                          SelectableText(
                            shown,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          if (tickets > 0) ...[
                            const SizedBox(height: AppSpace.s1),
                            Text(
                              l.s0502_passTickets(tickets),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: secondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  l.s0502_passHint,
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pass QR alone, big, on white, with the screen at full brightness
/// while it is open (Decision 18/19). Also S11.04-entry's full screen.
class PassFullScreen extends ConsumerStatefulWidget {
  const PassFullScreen({super.key, required this.code});

  /// What the QR encodes and the line under it (`VE-XXXX-XXXX`).
  final String code;

  @override
  ConsumerState<PassFullScreen> createState() => _PassFullScreenState();
}

class _PassFullScreenState extends ConsumerState<PassFullScreen> {
  late final ScreenBrightness _brightness = ref.read(screenBrightnessProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_brightness.raise());
  }

  @override
  void dispose() {
    unawaited(_brightness.restore());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final side = (width - AppSpace.s8).clamp(160.0, 360.0);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: GestureDetector(
          key: const Key('pass-qr-full'),
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: QrImageView(
                      data: widget.code,
                      size: side,
                      backgroundColor: AppColors.surface,
                      padding: const EdgeInsets.all(AppSpace.s4),
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      semanticsLabel: l.ticketCodeSemantics(widget.code),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    widget.code,
                    style: const TextStyle(
                      color: AppColors.onScrim,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpace.s4),
                  AppButton.outline(
                    l.ticketQrClose,
                    onPressed: () => Navigator.of(context).pop(),
                    size: AppButtonSize.small,
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
