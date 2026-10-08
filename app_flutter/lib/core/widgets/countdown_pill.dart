// lib/core/widgets/countdown_pill.dart

import 'package:flutter/material.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/countdown.dart'
    show isCountdownAnnounceSecond;

/// Small pill with the time left (mock `.st.live`): "Còn 14:32", or "Hết hạn"
/// at zero. A live region only at 5 min, 1 min, 10 s and zero, so a screen
/// reader hears "QR còn hiệu lực 5 phút 0 giây" there and is not interrupted
/// every second. The caller owns the clock and passes [remaining].
class CountdownPill extends StatelessWidget {
  const CountdownPill({super.key, required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final expired = remaining <= Duration.zero;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final text = expired
        ? l10n.payQrExpiredPill
        : l10n.payQrCountdown(
            '${minutes.toString().padLeft(2, '0')}:'
            '${seconds.toString().padLeft(2, '0')}',
          );

    return Semantics(
      // The label follows every second, but only the coarse thresholds and
      // zero are announced (WCAG 4.1.3).
      liveRegion: isCountdownAnnounceSecond(remaining.inSeconds),
      label: expired
          ? l10n.payQrExpired
          : l10n.payQrCountdownSemantics(minutes, seconds),
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.secondary,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s2,
              vertical: AppSpace.s1,
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: AppText.xs2,
                fontWeight: FontWeight.w600,
                color: expired ? scheme.error : scheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
