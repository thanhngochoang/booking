import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/award_chip.dart';
import 'package:photobooking/core/widgets/status_badge.dart';
import 'package:photobooking/data/award/award.dart';

/// Award list row (S25.01 and the read-only list): disc (gold only when
/// approved or read-only), bold title, status pill as text and a sub line.
class AwardRow extends StatelessWidget {
  const AwardRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.status,
    this.statusLabel,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final String subtitle;

  /// Null = read-only list: no badge, gold disc.
  final AwardStatus? status;

  /// Overrides the default label of [status].
  final String? statusLabel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final s = status;
    final label = s == null ? null : (statusLabel ?? awardStatusLabel(l, s));
    final gold = s == null || s == AwardStatus.approved;
    final radius = BorderRadius.circular(AppRadius.md);
    return Semantics(
      label: label == null
          ? l.awardChipSemantics(title, subtitle)
          : l.awardRowSemantics(title, subtitle, label),
      button: onTap != null,
      excludeSemantics: true,
      child: Material(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s3,
                vertical: AppSpace.s2,
              ),
              child: Row(
                children: [
                  AwardDisc(gold: gold),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: AppText.base2,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s1),
                        Row(
                          children: [
                            if (label != null) ...[
                              _statusBadge(s!, label),
                              const SizedBox(width: AppSpace.s2),
                            ],
                            Expanded(
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppText.xs2,
                                  color: fgSec,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

/// Badge colours follow the mock (.b-ok / .b-pen / .b-warn / .b-bad) and the
/// booking badges.
StatusBadge _statusBadge(AwardStatus status, String label) {
  final (bg, on) = switch (status) {
    AwardStatus.approved => (
      AppColors.bookingAccepted,
      AppColors.foregroundInverse,
    ),
    AwardStatus.pending => (
      AppColors.bookingWaiting,
      AppColors.foregroundInverse,
    ),
    AwardStatus.needsInfo => (AppColors.bookingOpened, AppColors.foreground),
    AwardStatus.rejected || AwardStatus.revoked => (
      AppColors.bookingDenied,
      AppColors.foregroundInverse,
    ),
  };
  return StatusBadge.custom(
    key: const ValueKey('award_status_badge'),
    label: label,
    color: bg,
    onColor: on,
  );
}
