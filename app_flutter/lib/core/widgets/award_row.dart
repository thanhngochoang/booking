import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/award_chip.dart';
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
                              _StatusPill(
                                key: const ValueKey('award_status_badge'),
                                label: label,
                                status: s!,
                              ),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({super.key, required this.label, required this.status});

  final String label;
  final AwardStatus status;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg) = switch (status) {
      AwardStatus.approved => (
        dark ? AppColorsDark.goldSoft : AppColors.goldSoft,
        dark ? AppColorsDark.gold : AppColors.gold,
      ),
      AwardStatus.rejected || AwardStatus.revoked => (
        AppColors.errorSubtle,
        AppColors.destructivePressed,
      ),
      AwardStatus.needsInfo => (AppColors.warningSubtle, AppColors.pillInk),
      AwardStatus.pending => (
        dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
        dark
            ? AppColorsDark.foregroundSecondary
            : AppColors.foregroundSecondary,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1 / 2,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppText.xs,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}
