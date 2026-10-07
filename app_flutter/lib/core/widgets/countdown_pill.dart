// lib/core/widgets/countdown_pill.dart

import 'package:flutter/material.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

/// Small pill with the time left (mock `.st.live`): "Còn 14:32", or "Hết hạn"
/// at zero. A live region, so a screen reader hears "QR còn hiệu lực 14 phút
/// 32 giây" as it changes. The caller owns the clock and passes [remaining].
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
      liveRegion: true,
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
